const { ethers } = require("hardhat");
// const stakingnAbi = require("./utils/stakingAbi.json");
// const stakingContractAddress = "0x11D7Ab7481f1EbA649fEA8bE594a28F151e17958";

const stakingnAbi = require("./utils/proxyStakingAbi.json");
// const stakingContractAddress = "0x307c5eb0f6AE4c0c14c9BAA7F5aEdBbE71F06b73";
const stakingContractAddress = "0xef326CdAdA59D3A740A76bB5f4F88Fb2f1076164";

const tokenAbi = require("./utils/tokenAbi.json");

const token1ContractAddress = "0x1bFe4298796198F8664B18A98640CEc7C89b5BAa";
const token2ContractAddress = "0xEF52501F1062dE28106602A7fda41b8A285f8dD9";

let zero = "0x0000000000000000000000000000000000000000";

let provider;

async function main() {
  createPool();
}

function getContract(address, abi) {
  return new ethers.Contract(address, abi, getSigner());
}

function getPrivateKey() {
  return process.env.PRIVATE_KEY;
}

function getSigner() {
  return new ethers.Wallet(getPrivateKey(), getProvider());
}

function getProvider() {
  if (process.env.ETHEREUM_NETWORK == "goerli") {
    provider = new ethers.JsonRpcProvider(
      "https://goerli.infura.io/v3/b17715f3b04d4ccb90389a946de9c598"
    );
    return provider;
  } else {
    return "Not Valid Network";
    // new ethers.providers.StaticJsonRpcProvider(process.env.BSC_URL);
  }
}

async function createPool() {
  console.log("Current Signer: ", await getSigner());

  const stakingContractAbi = stakingnAbi;
  const contract = getContract(stakingContractAddress, stakingContractAbi);

  // let data = [
  //   "Prospera 1.0",
  //   1693828889,
  //   "0xEF52501F1062dE28106602A7fda41b8A285f8dD9",
  //   "0x0000000000000000000000000000000000000000",
  //   4500,
  //   ethers.parseUnits("500", "ether"),
  //   0,
  //   47088000,
  //   2592000,
  //   2,
  //   2592000,
  //   0,
  //   0,
  //   0,
  //   "ipfs:QmQh3rBJRAhehb2w56hQQHXwWvcCFrdBiuSKSxjXYYkwkh/centher/6c1bbf30-45bc-11ee-b3f1-b769a1ba9d46.json",
  //   false,
  //   false,
  //   true,
  // ];

  let poolId = await contract.createPool.staticCall(
    [
      "Prospera 1.0",
      1693828889,
      "0xEF52501F1062dE28106602A7fda41b8A285f8dD9",
      "0x0000000000000000000000000000000000000000",
      4500,
      ethers.parseUnits("500", "ether"),
      0,
      47088000,
      2592000,
      2,
      2592000,
      0,
      0,
      0,
      "ipfs:QmQh3rBJRAhehb2w56hQQHXwWvcCFrdBiuSKSxjXYYkwkh/centher/6c1bbf30-45bc-11ee-b3f1-b769a1ba9d46.json",
      false,
      false,
      true,
    ],
    {
      value: 10000000000000,
    }
  );

  console2.log("POOL ID: ", poolId);

  const tx = await contract.createPool(
    [
      "Prospera 1.0",
      1693828889,
      "0xEF52501F1062dE28106602A7fda41b8A285f8dD9",
      "0x0000000000000000000000000000000000000000",
      4500,
      ethers.parseUnits("500", "ether"),
      0,
      47088000,
      2592000,
      2,
      2592000,
      0,
      0,
      0,
      "ipfs:QmQh3rBJRAhehb2w56hQQHXwWvcCFrdBiuSKSxjXYYkwkh/centher/6c1bbf30-45bc-11ee-b3f1-b769a1ba9d46.json",
      false,
      false,
      true,
    ],
    { value: 10000000000000 }
  );

  await tx.wait();
  console.log("log:: tx details: ", tx.hash);
  // console.log("log:: tx details: ", tx.toString());

  // await contract.setAffiliateSetting(poolId, [100, 50, 25, 0, 0, 0]);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
