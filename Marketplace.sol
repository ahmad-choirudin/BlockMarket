// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title BlockMarket
/// @notice A simple decentralized marketplace for listing and purchasing items.
/// @dev Payments use the native currency of the network (for example, test ETH).
contract Marketplace {
    struct Item {
        uint256 id;
        address payable seller;
        string name;
        string description;
        uint256 price;
        uint256 quantity;
        bool active;
        bytes32 metadataHash;
    }

    address public immutable owner;
    uint256 public nextItemId = 1;
    uint256 public totalSales;
    uint256 public totalVolume;

    mapping(uint256 => Item) private items;
    mapping(address => uint256[]) private sellerItemIds;
    mapping(address => uint256) public purchaseCount;

    error EmptyName();
    error InvalidPrice();
    error InvalidQuantity();
    error ItemNotFound(uint256 itemId);
    error NotSeller(uint256 itemId, address caller);
    error ItemInactive(uint256 itemId);
    error OutOfStock(uint256 itemId);
    error CannotBuyOwnItem();
    error IncorrectPayment(uint256 expected, uint256 received);
    error TransferFailed();
    error NothingToWithdraw();

    event ItemListed(uint256 indexed itemId, address indexed seller, string name, uint256 price, uint256 quantity);
    event ItemUpdated(uint256 indexed itemId, string name, uint256 price, uint256 quantity, bool active);
    event ItemDeleted(uint256 indexed itemId, address indexed seller);
    event ItemPurchased(uint256 indexed itemId, address indexed buyer, address indexed seller, uint256 quantity, uint256 totalPrice);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);

    mapping(address => uint256) public pendingProceeds;

    constructor() {
        owner = msg.sender;
    }

    modifier onlySeller(uint256 itemId) {
        Item storage item = items[itemId];
        if (item.id == 0) revert ItemNotFound(itemId);
        if (item.seller != msg.sender) revert NotSeller(itemId, msg.sender);
        _;
    }

    /// @notice List an item for sale.
    /// @param name Human-readable item name.
    /// @param description Item description.
    /// @param price Price per unit in wei.
    /// @param quantity Available quantity.
    /// @param metadataHash Optional bytes32 hash pointing to off-chain metadata.
    function listItem(
        string calldata name,
        string calldata description,
        uint256 price,
        uint256 quantity,
        bytes32 metadataHash
    ) external returns (uint256 itemId) {
        if (bytes(name).length == 0) revert EmptyName();
        if (price == 0) revert InvalidPrice();
        if (quantity == 0) revert InvalidQuantity();

        itemId = nextItemId++;
        items[itemId] = Item({
            id: itemId,
            seller: payable(msg.sender),
            name: name,
            description: description,
            price: price,
            quantity: quantity,
            active: true,
            metadataHash: metadataHash
        });
        sellerItemIds[msg.sender].push(itemId);
        emit ItemListed(itemId, msg.sender, name, price, quantity);
    }

    /// @notice Update a listing. Setting quantity to zero is not allowed; use deleteItem to deactivate it.
    function updateItem(
        uint256 itemId,
        string calldata name,
        string calldata description,
        uint256 price,
        uint256 quantity,
        bytes32 metadataHash
    ) external onlySeller(itemId) {
        if (bytes(name).length == 0) revert EmptyName();
        if (price == 0) revert InvalidPrice();
        if (quantity == 0) revert InvalidQuantity();

        Item storage item = items[itemId];
        if (!item.active) revert ItemInactive(itemId);
        item.name = name;
        item.description = description;
        item.price = price;
        item.quantity = quantity;
        item.metadataHash = metadataHash;
        emit ItemUpdated(itemId, name, price, quantity, item.active);
    }

    /// @notice Deactivate a listing. Historical item data remains available on-chain.
    function deleteItem(uint256 itemId) external onlySeller(itemId) {
        Item storage item = items[itemId];
        if (!item.active) revert ItemInactive(itemId);
        item.active = false;
        emit ItemDeleted(itemId, msg.sender);
        emit ItemUpdated(itemId, item.name, item.price, item.quantity, false);
    }

    /// @notice Purchase one or more units. Payment is credited to the seller for later withdrawal.
    function buyItem(uint256 itemId, uint256 quantity) external payable {
        Item storage item = items[itemId];
        if (item.id == 0) revert ItemNotFound(itemId);
        if (!item.active) revert ItemInactive(itemId);
        if (msg.sender == item.seller) revert CannotBuyOwnItem();
        if (quantity == 0 || quantity > item.quantity) revert OutOfStock(itemId);

        uint256 totalPrice = item.price * quantity;
        if (msg.value != totalPrice) revert IncorrectPayment(totalPrice, msg.value);

        item.quantity -= quantity;
        if (item.quantity == 0) item.active = false;
        pendingProceeds[item.seller] += totalPrice;
        purchaseCount[msg.sender] += 1;
        totalSales += quantity;
        totalVolume += totalPrice;

        emit ItemPurchased(itemId, msg.sender, item.seller, quantity, totalPrice);
        if (!item.active) emit ItemUpdated(itemId, item.name, item.price, item.quantity, false);
    }

    /// @notice Withdraw accumulated sales proceeds using a pull-payment pattern.
    function withdrawProceeds() external {
        uint256 amount = pendingProceeds[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        pendingProceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
        emit ProceedsWithdrawn(msg.sender, amount);
    }

    function getItem(uint256 itemId) external view returns (Item memory) {
        if (items[itemId].id == 0) revert ItemNotFound(itemId);
        return items[itemId];
    }

    function getSellerItemIds(address seller) external view returns (uint256[] memory) {
        return sellerItemIds[seller];
    }
}
