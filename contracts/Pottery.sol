// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Pottery is Ownable {
    struct Quiz {
        uint8[] keys;
        bytes32 keysHash;
        uint256 endTimestamp;
        uint256 rewards; // total reward tokens
        uint256 totalPoints;
    }

    Quiz[] quizzes;

    mapping(address => mapping(uint256 => bytes32)) playerToAnswersHash;
    mapping(address => mapping(uint256 => uint256)) playerToPoint;
    mapping(address => mapping(uint256 => bool)) playerClaimed;

    function createQuiz(
        bytes32 keysHash,
        uint256 endTimestamp,
        uint256 rewards,
        uint256 total
    ) external onlyOwner returns (uint256) {
        Quiz memory newQuiz = Quiz({
            keys: new uint8[](total),
            keysHash: keysHash,
            endTimestamp: endTimestamp,
            rewards: rewards,
            totalPoints: 0
        });
        quizzes.push(newQuiz);
        return quizzes.length - 1;
    }

    function revealKeys(
        uint256 quizId,
        uint8[] memory keys,
        string calldata password
    ) external onlyOwner {
        // quiz state: ended
        Quiz storage quiz = quizzes[quizId];
        require(
            keccak256(abi.encodePacked(keys, password)) == quiz.keysHash
        );
        require(keys.length == quiz.keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            quiz.keys[i] = keys[i];
        }
    }

    function submitAnswer(uint256 quizId, bytes32 answersHash) external {
        // quiz state: started
        playerToAnswersHash[msg.sender][quizId] = answersHash;
    }

    function calculatePoint(
        uint256 quizId,
        uint8[] memory answers,
        string calldata seed
    ) external {
        // quiz state: keys revealed
        require(
            playerToAnswersHash[msg.sender][quizId] ==
                keccak256(abi.encodePacked(answers, seed))
        );
        Quiz memory quiz = quizzes[quizId];
        require(quiz.keys.length == answers.length);
        uint256 point;
        for (uint256 i = 0; i < answers.length; i++) {
            if (answers[i] == quiz.keys[i]) point++;
        }
        playerToPoint[msg.sender][quizId] = point;
        quiz.totalPoints += point;
    }

    function claimRewards(uint256 quizId) external {
        require(playerToPoint[msg.sender][quizId] > 0);
        require(!playerClaimed[msg.sender][quizId]);
        // transfer reward
        playerClaimed[msg.sender][quizId] = true;
    }
}
