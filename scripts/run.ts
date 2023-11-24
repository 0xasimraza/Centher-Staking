const { ethers } = require("hardhat");
const stakingnAbi = require("./utils/proxyStakingAbi.json"); // testnet
// const stakingnAbi = require("./utils/MainnetProxyStakingAbi.json"); //mainnet

const stakingContractAddress = "0xef326CdAdA59D3A740A76bB5f4F88Fb2f1076164"; //testnet
// const stakingContractAddress = "0xb2328A1Cd08F72B17ED32B17f76FcDfa383Bbd32"; //mainnet

const tokenAbi = require("./utils/tokenAbi.json");

const token1ContractAddress = "0x1bFe4298796198F8664B18A98640CEc7C89b5BAa";
const token2ContractAddress = "0xEF52501F1062dE28106602A7fda41b8A285f8dD9";

let zero = "0x0000000000000000000000000000000000000000";

let provider;

async function main() {
  createPool();
  // await createAllowance();
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
  // let arg = [
  //   "XYZ Project",
  //   Math.floor(Date.now() / 1000) + 900,
  //   "0x1bFe4298796198F8664B18A98640CEc7C89b5BAa",
  //   "0x0000000000000000000000000000000000000000",
  //   4500,
  //   ethers.parseUnits("500", "ether"),
  //   0,
  //   86400,
  //   600,
  //   2,
  //   600,
  //   0,
  //   0,
  //   0,
  //   "ipfs:QmZmrVzGGYcdppXZ3JXbWZi5ghPwazWmgZwKiujf66R7dd/centher/1bfa8070-4b2c-11ee-b82e-2f96bb0e5e83.json",
  //   false,
  //   false,
  //   true,
  //   100,
  // ];

  //dexa staking mainnet
  let arg = [
    "Supreme DeXa Staking",
    1700870400,
    "0x1bFe4298796198F8664B18A98640CEc7C89b5BAa",
    "0x0000000000000000000000000000000000000000",
    21600, // 216%
    ethers.parseUnits("25", "ether"),
    0,
    62899200,
    86400,
    2,
    0,
    0,
    0,
    0,
    "ipfs:QmNNq2ikQWXW6B7dVoXs6m8AMAisBtDUmtYkBd4XPvm1wa/centher/67f49e30-67ff-11ee-87e2-81594cb5404d.json",
    false,
    false,
    true,
    1000,
  ];
  try {
    let poolId = await contract.createPool.staticCall(arg, {
      value: 10000000000000,
    });

    console.log("POOL ID: ", poolId.toString());

    const tx1 = await contract.createPool(arg, {
      value: 10000000000000,
    });

    await tx1.wait();
    console.log("log:: Pool Created tx hash: ", tx1.hash);

    const tx2 = await contract.setAffiliateSetting(
      poolId,
      [200, 150, 150, 100, 100, 100]
    );

    await tx2.wait();
    console.log("log:: Reward Settings Created tx hash: ", tx2.hash);

    const tx3 = await contract.togglePoolNonRefundable(poolId, true);
    await tx3.wait();

    console.log("log:: togglePoolNonRefundable Created tx hash: ", tx3.hash);
  } catch (error) {
    console.log("ERROR: ", error);
  }
}

async function createAllowance() {
  console.log("Current Signer: ", await getSigner());

  const stakingContractAbi = stakingnAbi;
  const contract = getContract(stakingContractAddress, stakingContractAbi);

  let exPoolId = 6;
  let poolId = 11;
  let user = "0x3c801A4B155AD717D25ffE9D36Df441dd4761a47";
  let ref = "0x0000000000000000000000000000000000000000";
  let amount = ethers.parseEther("5000");

  try {
    // await contract.createAllowence.staticCall([
    //   exPoolId,
    //   poolId,
    //   amount,
    //   user,
    //   ref,
    // ]);

    let tx1 = await contract.createAllowence(
      exPoolId,
      poolId,
      amount,
      user,
      ref
    );
    await tx1.wait();
    console.log("hash: ", await tx1.hash);
  } catch (error) {
    console.log("error: ", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
