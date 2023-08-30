import { HardhatRuntimeEnvironment } from "hardhat/types/runtime";
export default async function deploy(
  params: any,
  hre: HardhatRuntimeEnvironment
): Promise<void> {
  const ethers = hre.ethers;
  const upgrades = hre.upgrades;

  const [account] = await ethers.getSigners();

  console.log(`1st account ${await account.address}`);

  const CentherStaking = await ethers.getContractFactory(
    "src/CentherStaking.sol:CentherStaking"
  );

  console.log("Deploying CentherStaking...");

  let args = [
    "0x538584360a8ec67338Ce73721585aC386d7a4e6E",
    "0xdD15D2650387Fb6FEDE27ae7392C402a393F8A37",
  ];

  //mainnet
  // let args = [
  //   "", //place centher registration
  //   "", //place platform address
  // ];

  // const instance = await upgrades.deployProxy(CentherStaking, args, {
  //   initializer: "initialize",
  // });

  // await instance.waitForDeployment();

  // await delay(26000);
  // console.log("Deployed Address", instance.target);

  // if (hre.network.name != "hardhat") {
  //   await hre.run("verify:verify", {
  //     address: instance.target,
  //     constructorArguments: [],
  //   });
  // }

  // Upgrading
  const CentherStakingV2 = await ethers.getContractFactory("CentherStaking");
  // const UPGRADEABLE_PROXY = "0xef326CdAdA59D3A740A76bB5f4F88Fb2f1076164"; //tetsnet
  const UPGRADEABLE_PROXY = ""; //mainnet
  const upgraded = await upgrades.upgradeProxy(
    UPGRADEABLE_PROXY,
    CentherStaking
  );
  await upgraded.waitForDeployment();
  await delay(26000);
  console.log("Deployed Address", await upgraded.target);

  if (hre.network.name != "hardhat") {
    await hre.run("verify:verify", {
      address: upgraded.target,
      constructorArguments: [],
    });
  }

  // for simple deployment
  // const instance = await CentherStaking.deploy(args[0], args[1]);
  // await instance.waitForDeployment();
  // await delay(26000);
  // console.log("Deployed Address", instance.target);

  // if (hre.network.name != "hardhat") {
  //   await hre.run("verify:verify", {
  //     address: instance.target,
  //     constructorArguments: args,
  //   });
  // }
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Proxy Contract: 0x736EaE71d8d7a011184187903539cdc692D0eddE
// Implementation Contract: 0xc470Df42128146BE8cC9fA734B23F9E3c5dCa672
