// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Fund is Ownable, Initializable, AccessControl {
    using SafeERC20 for IERC20;
    IERC20 public scales;
    uint256 public claimedAmount;
    bytes32 public constant HARVESTER_ROLE = keccak256("HARVESTER_ROLE");

    /*===================== CONSTRUCTOR =====================*/

    function initialize(address _scales) external initializer {
        require(_scales != address(0), "Fund::constructor: Invalid address");
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        scales = IERC20(_scales);
    }

    /*===================== VIEWS =====================*/

    function allocation() public view virtual returns (uint256);

    function vestingStart() public view virtual returns (uint256);

    function vestingDuration() public view virtual returns (uint256);

    function currentBalance() public view returns (uint256) {
        return scales.balanceOf(address(this));
    }

    function vestedBalance() public view returns (uint256) {
        uint256 _allocation = allocation();
        uint256 _start = vestingStart();
        uint256 _duration = vestingDuration();
        if (block.timestamp <= _start) {
            return 0;
        }
        if (block.timestamp > _start + _duration) {
            return _allocation;
        }
        return (_allocation * (block.timestamp - _start)) / _duration;
    }

    function claimable() public view returns (uint256) {
        return vestedBalance() - claimedAmount;
    }

    /*===================== MUTATIVE =====================*/
    function harvestTo(address receiver, uint256 amount) onlyRole(HARVESTER_ROLE) external {
        require(receiver != address(0), "Fund::transfer: Invalid address");
        require(amount > 0, "Fund::transfer: Invalid amount");
        require(amount <= claimable(), "Fund::transfer: > vestedAmount");

        claimedAmount = claimedAmount + amount;
        scales.safeTransfer(receiver, amount);
    }
}
