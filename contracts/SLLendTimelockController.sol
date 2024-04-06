// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/governance/TimelockController.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external;
}

interface IMarket {
    function symbol() external view returns (string memory);

    function underlying() external view returns (address);

    function _reduceReserves(uint256 amount) external returns (uint256);
}

contract SLLendTimelockController is TimelockController {
    bytes32 public constant SL_ADMIN_ROLE = keccak256("SL_ADMIN_ROLE");
    bytes32 public constant RESERVES_ROLE = keccak256("RESERVES_ROLE");

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {
        _setRoleAdmin(SL_ADMIN_ROLE, SL_ADMIN_ROLE);
        _setRoleAdmin(RESERVES_ROLE, SL_ADMIN_ROLE);

        _setupRole(SL_ADMIN_ROLE, _msgSender());
        _setupRole(RESERVES_ROLE, _msgSender());
    }

    function _reduceReserves(
        address cToken,
        uint256 amount,
        address to
    ) public onlyRole(RESERVES_ROLE) {
        require(to != address(0), "SLLendTimelock: To cannot be zero");

        address underlying = IMarket(cToken).underlying();
        IERC20 token = IERC20(underlying);

        uint256 beforeBalance = token.balanceOf(address(this));
        IMarket(cToken)._reduceReserves(amount);
        uint256 afterBalance = token.balanceOf(address(this));

        token.transfer(to, afterBalance - beforeBalance);
    }
}
