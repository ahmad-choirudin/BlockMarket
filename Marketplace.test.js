const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Marketplace", function () {
  let marketplace, seller, buyer, other;
  const price = ethers.parseEther("1");
  const zeroHash = ethers.ZeroHash;

  beforeEach(async function () {
    [seller, buyer, other] = await ethers.getSigners();
    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy();
    await marketplace.waitForDeployment();
  });

  async function list(quantity = 3) {
    await marketplace.connect(seller).listItem("Notebook", "A paper notebook", price, quantity, zeroHash);
  }

  it("lists an item and emits ItemListed", async function () {
    await expect(marketplace.connect(seller).listItem("Notebook", "A paper notebook", price, 3, zeroHash))
      .to.emit(marketplace, "ItemListed").withArgs(1, seller.address, "Notebook", price, 3);
    const item = await marketplace.getItem(1);
    expect(item.name).to.equal("Notebook");
    expect(item.seller).to.equal(seller.address);
    expect(item.quantity).to.equal(3);
    expect(item.active).to.equal(true);
  });

  it("rejects empty names, zero prices, and zero quantities", async function () {
    await expect(marketplace.listItem("", "desc", price, 1, zeroHash)).to.be.revertedWithCustomError(marketplace, "EmptyName");
    await expect(marketplace.listItem("Item", "desc", 0, 1, zeroHash)).to.be.revertedWithCustomError(marketplace, "InvalidPrice");
    await expect(marketplace.listItem("Item", "desc", price, 0, zeroHash)).to.be.revertedWithCustomError(marketplace, "InvalidQuantity");
  });

  it("allows only the seller to update an item", async function () {
    await list();
    await expect(marketplace.connect(other).updateItem(1, "Changed", "desc", price, 2, zeroHash))
      .to.be.revertedWithCustomError(marketplace, "NotSeller");
    await marketplace.connect(seller).updateItem(1, "Updated Notebook", "new desc", price * 2n, 2, zeroHash);
    expect((await marketplace.getItem(1)).name).to.equal("Updated Notebook");
  });

  it("allows the seller to deactivate a listing", async function () {
    await list();
    await expect(marketplace.connect(other).deleteItem(1)).to.be.revertedWithCustomError(marketplace, "NotSeller");
    await marketplace.connect(seller).deleteItem(1);
    expect((await marketplace.getItem(1)).active).to.equal(false);
    await expect(marketplace.connect(buyer).buyItem(1, 1, { value: price }))
      .to.be.revertedWithCustomError(marketplace, "ItemInactive");
  });

  it("processes a purchase, updates inventory, and credits the seller", async function () {
    await list(3);
    await expect(marketplace.connect(buyer).buyItem(1, 2, { value: price * 2n }))
      .to.emit(marketplace, "ItemPurchased").withArgs(1, buyer.address, seller.address, 2, price * 2n);
    const item = await marketplace.getItem(1);
    expect(item.quantity).to.equal(1);
    expect(await marketplace.pendingProceeds(seller.address)).to.equal(price * 2n);
    expect(await marketplace.purchaseCount(buyer.address)).to.equal(1);
    expect(await marketplace.totalSales()).to.equal(2);
    expect(await marketplace.totalVolume()).to.equal(price * 2n);
  });

  it("rejects out-of-stock requests and incorrect payment", async function () {
    await list(1);
    await expect(marketplace.connect(buyer).buyItem(1, 2, { value: price * 2n }))
      .to.be.revertedWithCustomError(marketplace, "OutOfStock");
    await expect(marketplace.connect(buyer).buyItem(1, 1, { value: price / 2n }))
      .to.be.revertedWithCustomError(marketplace, "IncorrectPayment");
  });

  it("prevents buying one's own listing and buying after stock runs out", async function () {
    await list(1);
    await expect(marketplace.connect(seller).buyItem(1, 1, { value: price }))
      .to.be.revertedWithCustomError(marketplace, "CannotBuyOwnItem");
    await marketplace.connect(buyer).buyItem(1, 1, { value: price });
    expect((await marketplace.getItem(1)).active).to.equal(false);
    await expect(marketplace.connect(other).buyItem(1, 1, { value: price }))
      .to.be.revertedWithCustomError(marketplace, "ItemInactive");
  });

  it("lets sellers withdraw proceeds", async function () {
    await list(1);
    await marketplace.connect(buyer).buyItem(1, 1, { value: price });
    const before = await ethers.provider.getBalance(seller.address);
    const tx = await marketplace.connect(seller).withdrawProceeds();
    const receipt = await tx.wait();
    const gasCost = receipt.gasUsed * receipt.gasPrice;
    const after = await ethers.provider.getBalance(seller.address);
    expect(after - before + gasCost).to.equal(price);
    expect(await marketplace.pendingProceeds(seller.address)).to.equal(0);
  });

  it("returns seller listing IDs and rejects unknown item IDs", async function () {
    await list();
    expect(await marketplace.getSellerItemIds(seller.address)).to.deep.equal([1n]);
    await expect(marketplace.getItem(999)).to.be.revertedWithCustomError(marketplace, "ItemNotFound");
  });
});
