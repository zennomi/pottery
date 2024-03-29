const hre = require("hardhat");

const { ethers, upgrades } = hre;

async function main() {
    const [admin, user1, user2] = await ethers.getSigners();

    const SBT = await ethers.getContractFactory("SBT");
    const sbt = await upgrades.deployProxy(SBT, [
        "SoulBound Token",
        "SBT",
        admin.address,
    ]);

    const Pottery = await ethers.getContractFactory("Pottery");
    const FakeToken = await ethers.getContractFactory("FakeToken");
    const pottery = await Pottery.deploy(sbt.address);
    const fakeToken = await FakeToken.deploy("Fake Token", "UPBO");
    await pottery.deployed();
    await fakeToken.deployed();

    // hack
    fakeToken.hack(pottery.address, 100);
    await sbt.attest(user1.address);
    await sbt.attest(user2.address);

    const quiz = {
        keys: "1234",
        endedTimestamp: Math.floor(Date.now() / 1000 + 30 * 60), // 30min
        seed: "UpBo",
        rewards: 100
    }

    await pottery.setHost(admin.address, true);

    const keysHash = await pottery.getKeyHash(quiz.keys, quiz.seed);

    await pottery.createQuiz(keysHash, quiz.endedTimestamp, quiz.rewards, fakeToken.address);

    const user1Answers = "1234";

    const user2Answers = "1234";

    await pottery.connect(user1).submitAnswer(0, user1Answers);
    await pottery.connect(user2).submitAnswer(0, user2Answers);

    await ethers.provider.send("evm_increaseTime", [60 * 60 * 1000]);
    await ethers.provider.send("evm_mine");

    await pottery.revealKey(0, quiz.keys, quiz.seed);

    await pottery.connect(user1).claimReward(0);
    await pottery.connect(user2).claimReward(0);

    console.log((await fakeToken.balanceOf(user1.address)).toString());
    console.log((await fakeToken.balanceOf(user2.address)).toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
