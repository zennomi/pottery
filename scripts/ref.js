const hre = require("hardhat");

const { ethers, upgrades } = hre;

async function main() {
    const [admin, user1, user2, user3, user4, pottery] = await ethers.getSigners();
    const Referral = await ethers.getContractFactory("Referral");
    const FakeToken = await ethers.getContractFactory("FakeToken");
    const referral = await Referral.deploy(admin.address);
    const fakeToken = await FakeToken.deploy("Fake Token", "UPBO");
    await referral.deployed();
    await fakeToken.deployed();

    fakeToken.hack(pottery.address, 100);
    // fakeToken.hack(user2.address, 100);
    // fakeToken.hack(user3.address, 100);
    // fakeToken.hack(user4.address, 100);
    fakeToken.connect(pottery).approve(referral.address, 100);
    // fakeToken.connect(user2).approve(referral.address, 100);
    // fakeToken.connect(user3).approve(referral.address, 100);
    // fakeToken.connect(user4).approve(referral.address, 100);

    // console.log(await fakeToken.balanceOf(user2.address));
    console.log();

    await referral.connect(user1).register();
    await referral.connect(user2).register();
    await referral.connect(admin).register();
    await referral.connect(user1).addReferrer(admin.address);
    await referral.connect(user2).addReferrer(user1.address);
    await referral.connect(user3).addReferrer(user2.address);
    await referral.connect(user4).addReferrer(user2.address);

    await referral.connect(pottery).payReferral(user2.address, fakeToken.address, 100);

    console.log(await fakeToken.balanceOf(admin.address));
    console.log(await fakeToken.balanceOf(user1.address));
    console.log(await fakeToken.balanceOf(user2.address));
    console.log(await fakeToken.balanceOf(user3.address));
    console.log(await fakeToken.balanceOf(user4.address));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
