// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Referral is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint8 constant MAX_REFEREES = 3;
    address private dev;

    mapping(address => address) public referrerOf;
    mapping(address => EnumerableSet.AddressSet) refereesOf;
    mapping(address => bool) registered;

    event Registed(address referrer);
    event AddReferer(address referee, address referrer);
    event PaidReferral(address from, address to, uint amount, uint level); // from is 2, referer of from is 1,...

    constructor(address _dev) {
        dev = _dev;
    }

    function register() public {
        require(!registered[msg.sender], "User registered");
        registered[msg.sender] = true;
        emit Registed(msg.sender);
    }

    function addReferrer(address referrer) public {
        require(registered[referrer], "Referrer has not registered yet");
        EnumerableSet.AddressSet storage referees = refereesOf[referrer];
        require(
            referees.length() <= MAX_REFEREES,
            "Referrer had already had 5 referees"
        );
        require(referrerOf[msg.sender] == address(0), "User added a referer");
        referees.add(msg.sender);
        referrerOf[msg.sender] = referrer;
        emit AddReferer(msg.sender, referrer);
    }

    function payReferral(
        address from,
        address tokenAddress,
        uint256 amount
    ) public {
        IERC20 token = IERC20(tokenAddress);
        address referrer = referrerOf[from];
        uint256 remain = amount;
        if (referrer != address(0)) {
            uint256 refererAmount = (3 * amount) / 10;
            token.safeTransferFrom(msg.sender, referrer, refererAmount);
            remain -= refererAmount;
            emit PaidReferral(from, referrer, refererAmount, 1);
            address f0 = referrerOf[referrer];
            if (f0 != address(0)) {
                uint256 f0Amount = (2 * amount) / 10;
                token.safeTransferFrom(msg.sender, f0, f0Amount);
                remain -= f0Amount;
                emit PaidReferral(from, f0, refererAmount, 0);
            }
        }
        uint256 refereeCount = refereesOf[from].length();
        if (refereeCount > 0) {
            EnumerableSet.AddressSet storage referees = refereesOf[from];
            uint256 refereeAmount = (1 * amount) / 10;
            for (uint256 i; i < refereeCount; i++) {
                address referee = referees.at(i);
                token.safeTransferFrom(msg.sender, referee, refereeAmount);
                remain -= refereeAmount;
                emit PaidReferral(from, referee, refereeAmount, 3);
            }
        }
        token.safeTransferFrom(msg.sender, dev, remain - amount / 9);
    }

    function refCount(address user) public view returns (uint256) {
        return refereesOf[user].length();
    }
}
