const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts, deployer address:", deployer.address);

  const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
  const mockUSDC = await MockUSDC.deploy();
  await mockUSDC.waitForDeployment();
  const usdcAddress = await mockUSDC.getAddress();
  console.log("✅ MockUSDC deployed successfully:", usdcAddress);

  const SolarShare = await hre.ethers.getContractFactory("SolarShare");
  const solarShare = await SolarShare.deploy(
    "SolarShare Token", 
    "SST", 
    deployer.address
  ); 

  await solarShare.waitForDeployment();
  const shareAddress = await solarShare.getAddress();
  console.log("✅ SolarShare deployed successfully:", shareAddress);

  const SolarGovernance = await hre.ethers.getContractFactory("SolarGovernance");
  const governance = await SolarGovernance.deploy(
    shareAddress, 
    deployer.address
  );
  await governance.waitForDeployment();
  const govAddress = await governance.getAddress();
  console.log("✅ SolarGovernance deployed successfully:", govAddress);

  const SolarFactory = await hre.ethers.getContractFactory("SolarFactory");
  const factory = await SolarFactory.deploy(); 
  await factory.waitForDeployment();
  const factoryAddress = await factory.getAddress();
  console.log("✅ SolarFactory deployed successfully:", factoryAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
