// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ISBT721.sol";

contract Pottery is Ownable {
    using SafeERC20 for IERC20;

    enum QuizState {
        OPEN,
        FINISHED
    }

    struct Quiz {
        string key; // reveal later
        bytes32 keyHash; // don't let admin úp bô
        uint256 endedTimestamp; // player can't submit answers anymore
        uint256 rewardAmount; // total reward tokens
        address tokenAddress; // reward's address
        QuizState state;
    }

    Quiz[] internal quizzes;
    ISBT721 internal babToken;
    EnumerableSet.UintSet internal activeQuizList;

    mapping(address => bool) hosts;

    mapping(uint256 => mapping(string => uint256)) internal quizToAnswerCount;
    mapping(address => mapping(uint256 => string)) internal playerToAnswer;
    mapping(address => mapping(uint256 => bool)) internal playerClaimed;

    constructor(address _babAddress) {
        babToken = ISBT721(_babAddress);
    }

    /*  ╔══════════════════════════════╗
        ║            EVENTS            ║
        ╚══════════════════════════════╝ */

    event QuizOpen(
        uint256 quizId,
        uint256 endedTimestamp,
        uint256 rewardAmount,
        address tokenAddress
    );

    event QuizFinished(uint256 quizId, string key, uint256 timestamp);

    event UserSubmit(uint256 quizId, address player, uint256 timestamp);

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

    function _validateKey(
        bytes32 _hash,
        string memory _key,
        string memory _seed
    ) internal pure returns (bool) {
        if (_hash == sha256(abi.encodePacked(_key, _seed))) {
            return true;
        } else {
            return false;
        }
    }

    /*  ╔══════════════════════════════╗
        ║       EXTERNAL FUNCTIONS     ║
        ╚══════════════════════════════╝ */

    function createQuiz(
        bytes32 keyHash,
        uint256 endedTimestamp,
        uint256 rewardAmount,
        address tokenAddress
    ) external onlyHost returns (uint256) {
        Quiz memory newQuiz = Quiz({
            key: "",
            keyHash: keyHash,
            endedTimestamp: endedTimestamp,
            rewardAmount: rewardAmount,
            tokenAddress: tokenAddress,
            state: QuizState.OPEN
        });
        quizzes.push(newQuiz);
        uint256 newQuizId = quizzes.length - 1;
        EnumerableSet.add(activeQuizList, newQuizId);
        emit QuizOpen(newQuizId, endedTimestamp, rewardAmount, tokenAddress);
        return newQuizId;
    }

    function revealKey(
        uint256 quizId,
        string calldata key,
        string calldata seed
    ) external onlyHost validQuiz(quizId) {
        Quiz storage quiz = quizzes[quizId];
        require(quiz.endedTimestamp < block.timestamp, "Quiz has not ended");
        require(quiz.state == QuizState.OPEN, "Already revealed key");
        require(_validateKey(quiz.keyHash, key, seed), "Invalid key");
        quiz.key = key;
        EnumerableSet.remove(activeQuizList, quizId);
        emit QuizFinished(quizId, key, block.timestamp);
    }

    function submitAnswer(
        uint256 quizId,
        string calldata answer
    ) external validQuiz(quizId) {
        require(_validatePlayer(msg.sender), "User does not have bab token");
        Quiz memory quiz = quizzes[quizId];
        require(quiz.state == QuizState.OPEN, "Already revealed key");
        require(quiz.endedTimestamp >= block.timestamp, "Quiz ended");
        playerToAnswer[msg.sender][quizId] = answer;
        quizToAnswerCount[quizId][answer]++;
        emit UserSubmit(quizId, msg.sender, block.timestamp);
    }

    function claimReward(uint256 quizId) external validQuiz(quizId) {
        Quiz memory quiz = quizzes[quizId];
        require(
            quiz.state != QuizState.FINISHED,
            "Cannot claim now"
        );
        require(
            keccak256(abi.encodePacked((playerToAnswer[msg.sender][quizId]))) == keccak256(abi.encodePacked((quiz.key))),
            "Wrong answer"
        );
        require(!playerClaimed[msg.sender][quizId], "Already claimed");
        // transfer reward
        playerClaimed[msg.sender][quizId] = true;
        uint256 playerRewards = quiz.rewardAmount / quizToAnswerCount[quizId][quiz.key];
        IERC20(quiz.tokenAddress).safeTransfer(msg.sender, playerRewards);
        emit UserClaim(quizId, msg.sender, playerRewards);
    }

    /*╔══════════════════════════════╗
      ║            GETTERS           ║
      ╚══════════════════════════════╝ */

    function getKeyHash(
        string memory key,
        string memory seed
    ) external pure returns (bytes32) {
        return sha256(abi.encodePacked(key, seed));
    }

    function getQuizInfo(uint256 _quizId) external view returns (Quiz memory) {
        return quizzes[_quizId];
    }

    function getAnswer(uint256 _quizId) external view returns (string memory) {
        return playerToAnswer[msg.sender][_quizId];
    }

    function getActiveQuizCount() external view returns (uint256) {
        return EnumerableSet.length(activeQuizList);
    }
}
