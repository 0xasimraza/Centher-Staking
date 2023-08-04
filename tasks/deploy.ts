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
  // console.log("account.address: ", account.address);
  console.log("Deploying CentherStaking...");

  let args = [
    "0x538584360a8ec67338Ce73721585aC386d7a4e6E",
    "0xdD15D2650387Fb6FEDE27ae7392C402a393F8A37",
  ];

  // const instance = await upgrades.deployProxy(CentherStaking, args, {
  //   initializer: "initialize",
  // });

  // await instance.waitForDeployment();

  // await delay(26000);
  // console.log("Deployed Address", instance.target);

  // Upgrading
  const CentherStakingV2 = await ethers.getContractFactory("CentherStaking");
  const UPGRADEABLE_PROXY = "0x64b7DdFEc24a10B071B26315aA4E183e6Ae2Fd89";
  const upgraded = await upgrades.upgradeProxy(
    UPGRADEABLE_PROXY,
    CentherStaking
  );
  await upgraded.waitForDeployment();
  console.log("Deployed Address", await upgraded.target);

  if (hre.network.name != "hardhat") {
    await hre.run("verify:verify", {
      address: upgraded.target,
      constructorArguments: [],
    });
  }

  // for simple deployment

  // const instance = await CentherStaking.deploy(args[0],args[1])
  //  await instance.waitForDeployment();
  //  await delay(26000);
  //  console.log("Deployed Address", instance.target);

  // if (hre.network.name != "hardhat") {
  //   await hre.run("verify:verify", {
  //     address: "0xaDD719301F34945d13f3E667A8d095664E90cA9d",
  //     constructorArguments: args,
  //   });
  // }
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// 1st account 0xdD15D2650387Fb6FEDE27ae7392C402a393F8A37
// Deploying CentherStaking...
// Deployed Address 0x64b7DdFEc24a10B071B26315aA4E183e6Ae2Fd89
// Verifying implementation: 0xF260D6BC8021C4537b4501f64fbcA522C646bc25
// Successfully submitted source code for contract
// src/CentherStaking.sol:CentherStaking at 0xF260D6BC8021C4537b4501f64fbcA522C646bc25
// for verification on the block explorer. Waiting for verification result...
// Successfully verified contract CentherStaking on the block explorer.
// https://goerli.etherscan.io/address/0xF260D6BC8021C4537b4501f64fbcA522C646bc25#code
// Verifying proxy: 0x64b7DdFEc24a10B071B26315aA4E183e6Ae2Fd89
// Contract at 0x64b7DdFEc24a10B071B26315aA4E183e6Ae2Fd89 already verified.
// Linking proxy 0x64b7DdFEc24a10B071B26315aA4E183e6Ae2Fd89 with implementation
// Successfully linked proxy to implementation.
// Verifying proxy admin: 0xb1D9ca077A6608B48F9c4F3901625DEB729CD49e
// Contract at 0xb1D9ca077A6608B48F9c4F3901625DEB729CD49e already verified.
// Proxy fully verified.
