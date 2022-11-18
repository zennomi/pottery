// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Pottery is Ownable {
    using SafeERC20 for IERC20;

    enum QuizState {
        Started, // game started
        Revealed // keys revealed
    }

    struct Quiz {
        uint8[] keys; // reveal later
        bytes32 keysHash; // don't let admin be úp bô
        uint256 endedTimestamp; // player can't submit answers anymore
        uint256 revealedTimestamp; // player can get their point now
        uint256 totalPoints; // total points of all players
        uint256 rewards; // total reward tokens
        address tokenAddress; // reward's address
        QuizState state;
    }

    uint256 public CALCULATING_TIME = 1 days; // period for player to get their rank and claim later

    Quiz[] quizzes;

    mapping(address => mapping(uint256 => bytes32)) playerToAnswersHash;
    mapping(address => mapping(uint256 => uint256)) playerToPoint;
    mapping(address => mapping(uint256 => bool)) playerClaimed;

    event QuizStarted(
        uint256 quizId,
        uint256 endedTimestamp,
        uint256 rewards,
        address tokenAddress
    );

    event KeysRevealed(
        uint256 quizId,
        uint8[] keys,
        uint256 timestamp
    );

    event UserSubmit(
        uint256 quizId,
        address player
    );

    event UserCalculate(
        uint256 quizId,
        address player,
        uint8[] answers,
        uint256 point
    );

    event UserClaim(
        uint256 quizId,
        address player,
        uint256 rewards
    );

    modifier validQuiz(uint256 quizId) {
        require(quizId < quizzes.length);
        _;
    }

    function createQuiz(
        bytes32 keysHash,
        uint256 endedTimestamp,
        uint256 quizCount,
        uint256 rewards,
        address tokenAddress
    ) external onlyOwner returns (uint256) {
        Quiz memory newQuiz = Quiz({
            keys: new uint8[](quizCount),
            keysHash: keysHash,
            endedTimestamp: endedTimestamp,
            revealedTimestamp: 0,
            totalPoints: 0,
            rewards: rewards,
            tokenAddress: tokenAddress,
            state: QuizState.Started
        });
        quizzes.push(newQuiz);
        uint256 newQuizId = quizzes.length - 1;
        emit QuizStarted(newQuizId, endedTimestamp, rewards, tokenAddress);
        return newQuizId;
    }

    function revealKeys(
        uint256 quizId,
        uint8[] memory keys,
        string calldata seed
    ) external onlyOwner validQuiz(quizId) {
        Quiz storage quiz = quizzes[quizId];
        require(quiz.endedTimestamp < block.timestamp);
        require(quiz.state == QuizState.Started);
        require(keccak256(abi.encodePacked(keys, seed)) == quiz.keysHash);
        require(keys.length == quiz.keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            quiz.keys[i] = keys[i];
        }
        quiz.revealedTimestamp = block.timestamp;
        quiz.state = QuizState.Revealed;
        emit KeysRevealed(quizId, keys, block.timestamp);
    }

    function submitAnswer(uint256 quizId, bytes32 answersHash)
        external
        validQuiz(quizId)
    {
        Quiz memory quiz = quizzes[quizId];
        require(quiz.state == QuizState.Started);
        require(quiz.endedTimestamp >= block.timestamp);
        playerToAnswersHash[msg.sender][quizId] = answersHash;
        emit UserSubmit(quizId, msg.sender);
    }

    function calculatePoint(
        uint256 quizId,
        uint8[] memory answers,
        string calldata seed
    ) external validQuiz(quizId) {
        require(
            playerToAnswersHash[msg.sender][quizId] ==
                keccak256(abi.encodePacked(answers, seed, msg.sender))
        );
        Quiz memory quiz = quizzes[quizId];
        require(quiz.state == QuizState.Revealed);
        require(quiz.keys.length == answers.length);
        uint256 point;
        for (uint256 i = 0; i < answers.length; i++) {
            if (answers[i] == quiz.keys[i]) point++;
        }
        playerToPoint[msg.sender][quizId] = point;
        quiz.totalPoints += point;
        emit UserCalculate(quizId, msg.sender, answers, point);
    }

    function claimRewards(uint256 quizId) external validQuiz(quizId) {
        Quiz memory quiz = quizzes[quizId];
        require(quiz.revealedTimestamp + CALCULATING_TIME < block.timestamp);
        require(playerToPoint[msg.sender][quizId] > 0);
        require(!playerClaimed[msg.sender][quizId]);
        // transfer reward
        playerClaimed[msg.sender][quizId] = true;
        uint256 playerRewards = (playerToPoint[msg.sender][quizId] *
            quiz.rewards) / quiz.totalPoints;
        IERC20(quiz.tokenAddress).safeTransfer(msg.sender, playerRewards);
        emit UserClaim(quizId, msg.sender, playerRewards);
    }
}
