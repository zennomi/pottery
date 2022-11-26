// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ISBT721.sol";

contract Pottery is Ownable {
    using SafeERC20 for IERC20;

    enum QuizState {
        OPEN, // game started
        FINISHED // keys revealed
    }

    struct Quiz {
        uint8[] keys; // reveal later
        bytes32 keysHash; // don't let admin be úp bô
        uint256 endedTimestamp; // player can't submit answers anymore
        uint256 revealedTimestamp; // player can get their point now
        uint256 highestPoint;
        uint256 winnerCount;
        uint256 rewardAmount; // total reward tokens
        address tokenAddress; // reward's address
        QuizState state;
    }

    struct Answer {
        uint8[] options;
        uint256 timestamp;
    }

    uint256 public CALCULATING_TIME = 1 days; // period for player to get their rank and claim later

    Quiz[] internal quizzes;
    ISBT721 internal babToken;
    EnumerableSet.UintSet internal activeQuizList;

    mapping(address => bool) hosts;

    mapping(address => mapping(uint256 => Answer)) internal playerToAnswer;
    mapping(address => mapping(uint256 => uint256)) internal playerToPoint;
    mapping(address => mapping(uint256 => bool)) internal playerClaimed;

    constructor(address _babAddress) {
        babToken = ISBT721(_babAddress);
    }

    /*  ╔══════════════════════════════╗
        ║            EVENTS            ║
        ╚══════════════════════════════╝ */

    event QuizStarted(
        uint256 quizId,
        uint256 endedTimestamp,
        uint256 rewardAmount,
        address tokenAddress
    );

    event KeysRevealed(uint256 quizId, uint8[] keys, uint256 timestamp);

    event UserSubmit(uint256 quizId, address player, uint256 timestamp);

    event UserCalculate(uint256 quizId, address player, uint256 point);

    event UserClaim(uint256 quizId, address player, uint256 rewardAmount);

    modifier validQuiz(uint256 quizId) {
        require(quizId < quizzes.length, "Invalid quiz id");
        _;
    }

    modifier onlyHost() {
        require(hosts[msg.sender], "Not host");
        _;
    }

    /*  ╔══════════════════════════════╗
        ║        ADMIN FUNCTIONS       ║
        ╚══════════════════════════════╝ */

    function setHost(address user, bool isHost) external onlyOwner {
        hosts[user] = isHost;
    }

    /*  ╔══════════════════════════════╗
        ║       INTERNAL FUNCTION      ║
        ╚══════════════════════════════╝ */

    function _validatePlayer(address player) internal view returns (bool) {
        return babToken.balanceOf(player) > 0;
    }

    function _validateKeys(
        bytes32 _hash,
        uint8[] memory _keys,
        string memory _seed
    ) internal pure returns (bool) {
        if (_hash == sha256(abi.encodePacked(_keys, _seed))) {
            return true;
        } else {
            return false;
        }
    }

    /*  ╔══════════════════════════════╗
        ║       EXTERNAL FUNCTIONS     ║
        ╚══════════════════════════════╝ */

    function createQuiz(
        bytes32 keysHash,
        uint256 endedTimestamp,
        uint256 rewardAmount,
        address tokenAddress
    ) external onlyHost returns (uint256) {
        Quiz memory newQuiz = Quiz({
            keys: new uint8[](0),
            keysHash: keysHash,
            endedTimestamp: endedTimestamp,
            revealedTimestamp: 0,
            highestPoint: 0,
            winnerCount: 0,
            rewardAmount: rewardAmount,
            tokenAddress: tokenAddress,
            state: QuizState.OPEN
        });
        quizzes.push(newQuiz);
        uint256 newQuizId = quizzes.length - 1;
        EnumerableSet.add(activeQuizList, newQuizId);
        emit QuizStarted(newQuizId, endedTimestamp, rewardAmount, tokenAddress);
        return newQuizId;
    }

    function revealKeys(
        uint256 quizId,
        uint8[] memory keys,
        string calldata seed
    ) external onlyHost validQuiz(quizId) {
        Quiz storage quiz = quizzes[quizId];
        require(quiz.endedTimestamp < block.timestamp, "Quiz has not ended");
        require(quiz.state == QuizState.OPEN, "Invalid quiz state");
        require(_validateKeys(quiz.keysHash, keys, seed), "Invalid keys");
        quiz.keys = keys;
        quiz.revealedTimestamp = block.timestamp;
        quiz.state = QuizState.FINISHED;
        EnumerableSet.remove(activeQuizList, quizId);
        emit KeysRevealed(quizId, keys, block.timestamp);
    }

    function submitAnswer(
        uint256 quizId,
        uint8[] memory options
    ) external validQuiz(quizId) {
        require(_validatePlayer(msg.sender), "User does not have bab token");
        Quiz memory quiz = quizzes[quizId];
        require(quiz.state == QuizState.OPEN, "Invalid state");
        require(quiz.endedTimestamp >= block.timestamp, "Quiz ended");
        playerToAnswer[msg.sender][quizId] = Answer({
            options: options,
            timestamp: block.timestamp
        });
        emit UserSubmit(quizId, msg.sender, block.timestamp);
    }

    function calculatePoint(uint256 quizId) external validQuiz(quizId) {
        Quiz storage quiz = quizzes[quizId];
        require(quiz.state == QuizState.FINISHED, "Invalid state");
        require(
            playerToAnswer[msg.sender][quizId].timestamp > 0,
            "Not join yet"
        );
        uint8[] memory userOptions = playerToAnswer[msg.sender][quizId].options;
        require(
            quiz.keys.length == userOptions.length,
            "Invalid answers length"
        );
        uint256 point;
        for (uint256 i = 0; i < userOptions.length; i++) {
            if (userOptions[i] == quiz.keys[i]) point++;
        }
        playerToPoint[msg.sender][quizId] = point;
        if (quiz.highestPoint == point) {
            quiz.winnerCount++;
        } else if (quiz.highestPoint < point) {
            quiz.highestPoint = point;
            quiz.winnerCount = 1;
        }
        emit UserCalculate(quizId, msg.sender, point);
    }

    function claimReward(uint256 quizId) external validQuiz(quizId) {
        Quiz memory quiz = quizzes[quizId];
        require(
            quiz.revealedTimestamp + CALCULATING_TIME < block.timestamp,
            "Cannot claim now"
        );
        require(quiz.winnerCount > 0, "No one won this quiz");
        require(
            playerToPoint[msg.sender][quizId] == quiz.highestPoint,
            "Not enough rewards"
        );
        require(!playerClaimed[msg.sender][quizId], "Already claimed");
        // transfer reward
        playerClaimed[msg.sender][quizId] = true;
        uint256 playerRewards = quiz.rewardAmount / quiz.winnerCount;
        IERC20(quiz.tokenAddress).safeTransfer(msg.sender, playerRewards);
        emit UserClaim(quizId, msg.sender, playerRewards);
    }

    /*╔══════════════════════════════╗
      ║            GETTERS           ║
      ╚══════════════════════════════╝ */

    function getKeysHash(
        uint8[] memory answers,
        string memory seed
    ) external pure returns (bytes32) {
        return sha256(abi.encodePacked(answers, seed));
    }

    function getQuizInfo(uint256 _quizId) external view returns (Quiz memory) {
        return quizzes[_quizId];
    }

    function getAnswer(uint256 _quizId) external view returns (Answer memory) {
        return playerToAnswer[msg.sender][_quizId];
    }

    function getPoint(uint256 _quizId) external view returns (uint256) {
        return playerToPoint[msg.sender][_quizId];
    }

    function getActiveQuizCount() external view returns (uint256) {
        return EnumerableSet.length(activeQuizList);
    }
}
