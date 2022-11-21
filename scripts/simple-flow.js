const hre = require("hardhat");

const { ethers } = hre;

async function main() {
    const Pottery = await hre.ethers.getContractFactory("Pottery");
    const FakeToken = await hre.ethers.getContractFactory("FakeToken");
    const pottery = await Pottery.deploy();
    const fakeToken = await FakeToken.deploy("Fake Token", "UPBO");
    await pottery.deployed();
    await fakeToken.deployed();
    fakeToken.hack(pottery.address, 100);

    const [admin, user1, user2] = await ethers.getSigners();

    const quiz = {
        keys: [1, 2, 3, 4],
        endedTimestamp: Math.floor(Date.now() / 1000 + 30 * 60), // 30min
        seed: "UpBo",
        rewards: 100
    }

    await pottery.setHost(admin.address, true);

    const keysHash = await pottery.getKeysHash(quiz.keys, quiz.seed);

    await pottery.createQuiz(keysHash, quiz.endedTimestamp, quiz.rewards, fakeToken.address);

    const user1Answers = [1, 2, 3, 4];
    const user1AnswersHash = await pottery.getAnswersHash(user1.address, user1Answers, 'user1');

    const user2Answers = [1, 2, 4, 3];
    const user2AnswersHash = await pottery.getAnswersHash(user2.address, user2Answers, 'user2');

    await pottery.connect(user1).submitAnswer(0, user1AnswersHash);
    await pottery.connect(user2).submitAnswer(0, user2AnswersHash);

    await ethers.provider.send("evm_increaseTime", [60 * 60 * 1000]);
    await ethers.provider.send("evm_mine");

    await pottery.revealKeys(0, quiz.keys, quiz.seed);

    await pottery.connect(user1).calculatePoint(0, user1Answers, 'user1');
    await pottery.connect(user2).calculatePoint(0, user2Answers, 'user2');

    await ethers.provider.send("evm_increaseTime", [25 * 60 * 60 * 1000]);
    await ethers.provider.send("evm_mine");

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
