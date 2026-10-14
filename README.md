# BlockMarket — Decentralized Marketplace Smart Contract

BlockMarket is a learning project that demonstrates a peer-to-peer marketplace implemented in Solidity. Sellers can list and manage items; buyers can purchase available quantities using the network's native currency. Seller proceeds are credited to the contract and withdrawn separately.

> **Status:** Educational project. It has not been independently audited and should not be used to hold real funds without professional review.

## Features

- List items with a name, description, unit price, quantity, seller address, active flag, and optional `bytes32` metadata hash.
- Update or deactivate listings; only the original seller may do so.
- Purchase one or more units with exact payment.
- Reject invalid names, zero prices/quantities, incorrect payments, inactive listings, out-of-stock purchases, and self-purchases.
- Emit events for listing, update, deletion, purchase, and withdrawals.
- Track seller listing IDs, buyer purchase counts, total units sold, total sales volume, and seller proceeds.
- Use a pull-payment withdrawal pattern rather than sending funds to sellers during purchase.
- Include automated tests for normal behavior and common failure cases.

## Project structure

```text
contracts/Marketplace.sol   Solidity smart contract
 test/Marketplace.test.js   Automated contract tests
hardhat.config.js           Hardhat configuration
package.json                Dependencies and scripts
```

## Requirements

- Node.js 18 or newer (Node.js 20 LTS recommended)
- npm
- Internet access for the initial dependency installation

A phone browser may open Remix IDE, but running Hardhat tests and managing a GitHub repository is usually easier on a computer. Remix can be used to compile and manually test the contract without installing Node.js.

## Install and test locally

```bash
npm install
npm test
npm run compile
```

The test suite uses Hardhat's local in-memory blockchain. It does not require real ETH or deployment to a public network.

## Deploy locally

Start a local node in one terminal:

```bash
npx hardhat node
```

In a second terminal, deploy using the Hardhat console or create a deployment script. Example using the console:

```bash
npx hardhat console --network localhost
```

Then in the console:

```javascript
const Marketplace = await ethers.getContractFactory("Marketplace");
const marketplace = await Marketplace.deploy();
await marketplace.waitForDeployment();
console.log(await marketplace.getAddress());
```

## Interacting with the contract

Examples below are intended for the Hardhat console after deployment. Replace `marketplace` with the deployed contract instance and use accounts from the local network.

### List an item

```javascript
const [seller, buyer] = await ethers.getSigners();
const price = ethers.parseEther("0.01");
const tx = await marketplace.connect(seller).listItem(
  "Notebook",
  "A paper notebook",
  price,
  10,
  ethers.ZeroHash
);
await tx.wait();
console.log(await marketplace.getItem(1));
```

### Buy an item

```javascript
await marketplace.connect(buyer).buyItem(1, 2, {
  value: price * 2n
});
console.log(await marketplace.getItem(1));
console.log(await marketplace.pendingProceeds(seller.address));
```

### Update or deactivate a listing

```javascript
await marketplace.connect(seller).updateItem(
  1, "Notebook - Updated", "Updated description", price, 8, ethers.ZeroHash
);
await marketplace.connect(seller).deleteItem(1);
```

### Withdraw seller proceeds

```javascript
await marketplace.connect(seller).withdrawProceeds();
```

## Contract design notes

- `storage` is used for persistent item records; calldata is used for external function inputs; returned structs are copied to memory.
- `address`, `uint256`, `bool`, `string`, and `bytes32` represent seller, prices/quantities, status, text, and optional metadata digest.
- Custom errors make failure cases explicit.
- Deleting a listing marks it inactive instead of erasing historical blockchain data.
- The contract accepts exact native-currency payment. It does not integrate ERC-20 tokens or an external payment gateway.
- `owner` is initialized in the constructor for demonstrating constructor state; no privileged owner-only operation is currently required.
- `totalSales` counts units sold, while `totalVolume` counts the total amount paid in the network's native currency base units.

## Security considerations and limitations

This is an educational implementation, not an audited production marketplace. Before handling real funds, obtain a professional security review and consider adding pagination, reentrancy-focused tests, purchase receipts/history indexing, an explicit marketplace fee model if needed, and a deployment/verification workflow. The contract uses checks-effects-interactions for withdrawals and records seller proceeds before the seller withdraws. On-chain strings can increase gas costs; the metadata hash is optional and does not itself validate off-chain content.

## License

MIT
