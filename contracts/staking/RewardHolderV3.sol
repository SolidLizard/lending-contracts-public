//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./libraries/SafeToken.sol";
import "./interfaces/IClaimable.sol";

contract RewardHolder is IClaimable, OwnableUpgradeable, AccessControlUpgradeable {
    using SafeToken for address;

    struct Reward {
        uint256 addTime;
        uint256 amount;
    }

    event RecipientUpdate(address oldRecipient, address newRecipient);

    // guy who can claim
    address public recipient;

    mapping(address => Reward) public lastRewards;
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");

    function initialize() public initializer {
        __Ownable_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /** Admin Functions */
    function _setRecipient(address newRecipient) public onlyOwner {
        require(
            newRecipient != address(0),
            "RewardHolder: recipient cannot be zero"
        );

        address oldRecipient = recipient;
        recipient = newRecipient;
        emit RecipientUpdate(oldRecipient, newRecipient);
    }

    function claim(address token) public returns (uint256 amount) {
        require(
            _msgSender() == recipient,
            "RewardHolder: only recipient can claim"
        );

        amount = token.balanceOf(address(this));
        if (amount > 0) {
            token.safeTransfer(_msgSender(), amount);
            emit Claim(token, _msgSender(), amount);
        }
    }

    function addRewards(uint256 amount, address token) public onlyRole(REWARDER_ROLE) {
        if (amount > 0) {
            if (amount == type(uint256).max) {
                amount = token.balanceOf(msg.sender);
            }

            token.safeTransferFrom(msg.sender, address(this), amount);
            lastRewards[address(token)].amount += amount;
            lastRewards[address(token)].addTime = block.timestamp;

        }
    }
    function setAdminRole() public onlyOwner{
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
