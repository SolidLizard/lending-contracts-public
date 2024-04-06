// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/math/SafeMath.sol";
import "./security/ReentrancyGuard.sol";
import "./access/Ownable.sol";
import "./interfaces/IRouter.sol";
import {ERC20Permit} from "./token/ERC20/extensions/ERC20Permit.sol";
import {IToken} from "./interfaces/IToken.sol";

import {ERC20} from "./token/ERC20/ERC20.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}


contract XSCALES is ReentrancyGuard,Ownable, ERC20Permit{
    using SafeMath for uint256;

    IToken public immutable TOKEN;
    address public  router;
    IWETH public immutable WETH;
 
    address public treasury;
    uint256 public exitRatio = 65; // 65%
    uint256 public nextVestingId = 1;
    
    event StartedVesting(address indexed account, uint256 amount, uint256 vestingId);
    event ClaimedVested(address indexed account, uint256 amount, uint256 vestingId);
    event DeleteVested(address indexed account, uint256 amount, uint256 id);
    event NewTreasury(address indexed account);


    struct Vesting {
        uint256 id;
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 lockedAmount;
        uint256 startTime;
    }

    mapping(address => mapping(uint256 => Vesting)) public vestings;

    mapping(address => uint256[]) public userVestingIds;

    constructor(address _token,address _router ,address _weth,address _treasury) ERC20("xSCALES", "xSCALES") ERC20Permit("xSCALES") {
        TOKEN = IToken(_token);
        router = _router;
        WETH = IWETH(_weth);
        treasury = _treasury;
        _mint(msg.sender, 6100000000000000000000000); // 6.1M (10M (total) - 1.5M (dev) - 2M (treasury) - 400k (liq))
    }

    function setRouter(address _router)  external onlyOwner{
        router = _router;
    }

    function setExitRatio(uint256 _exitRatio)  external onlyOwner{
        require(_exitRatio > 50,"exit ratio too low");
        exitRatio = _exitRatio;
    }

    function setTreasury(address _treasury)  external onlyOwner{
        treasury = _treasury;
        emit NewTreasury(treasury);
    }

    function startVesting(uint256 amount) external  nonReentrant {
        require(amount > 0,"error amount");
        require(balanceOf(msg.sender) >= amount, "Insufficient xScale balance");

        _burn(msg.sender, amount);
    
        Vesting memory newVesting = Vesting({
            id: nextVestingId,   
            totalAmount: amount,
            claimedAmount: 0,
            lockedAmount : amount,
            startTime: block.timestamp
        });
        vestings[msg.sender][nextVestingId] = newVesting;
        userVestingIds[msg.sender].push(nextVestingId);
        nextVestingId = nextVestingId.add(1);   
        emit StartedVesting(msg.sender, amount, newVesting.id);
    }
    
    function claimAll( ) external   {        
        uint256[] memory vestingIds = userVestingIds[msg.sender];
        require(vestingIds.length > 0);
        for(uint256 i=0;i<vestingIds.length;i++){
            _claimVestedById(vestingIds[i]);
        }
    }
    function claimVestedById(uint256 id) external  {        
        _claimVestedById(id);
    }

     function _claimVestedById(uint256 id) internal nonReentrant {        
        require(vestings[msg.sender][id].startTime != 0, "Invalid ID");  
        Vesting storage v = vestings[msg.sender][id];
        uint256 claimable = _calculateClaimable(v);
        require(claimable > 0, "Nothing to claim");
        v.claimedAmount = v.claimedAmount.add(claimable);
        v.lockedAmount = v.lockedAmount.sub(claimable) ;
        require(v.lockedAmount >= 0,"error lockedAmount");
        uint _balanceOf = TOKEN.balanceOf(address(this));
        if (_balanceOf < claimable) {
            TOKEN.mint(address(this), claimable - _balanceOf);
        }
        require(TOKEN.transfer(msg.sender, claimable), "Transfer failed");

        if (v.claimedAmount == v.totalAmount && block.timestamp.sub(v.startTime) >= 60 days
            && v.lockedAmount == 0
         ) {
            delete vestings[msg.sender][id];  // delete vesting
            _removeUserVesting(msg.sender,id);
            emit DeleteVested(msg.sender, claimable, id);
        }
        emit ClaimedVested(msg.sender, claimable, id);
    }
    function _removeUserVesting(address _user, uint256 _vestingId) internal {
        uint256[] storage vestingIds = userVestingIds[_user];
        uint256 index;
        bool found = false;

        for (uint256 i = 0; i < vestingIds.length; i++) {
            if (vestingIds[i] == _vestingId) {
                index = i;
                found = true;
                break;
            }
        }
        require(found, "Vesting ID not found");
        // Swap the found vesting ID with the last element
        vestingIds[index] = vestingIds[vestingIds.length - 1];
        // Remove the last element
        vestingIds.pop();
    }

    function calculateClaimable(address account,uint256 id) external view returns (uint256) {
        Vesting memory v = vestings[account][id];
        if(v.startTime == 0){
            return 0;
        }
        return _calculateClaimable(v);
    }
    function _calculateClaimable(Vesting memory v) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp.sub(v.startTime);
        uint256 claimable;
        if (timeElapsed >= 60 days) {
            claimable = v.totalAmount.sub(v.claimedAmount);
        } else {
            claimable = v.totalAmount.mul(timeElapsed).div(60 days).sub(v.claimedAmount);
        }
    
        return claimable; 
    }

    function getAllVesting(address account) public view returns ( Vesting[] memory ) {
        uint256[] memory vestingIds = userVestingIds[account];
        uint256 count = 0;
       for(uint256 i = 0;i < vestingIds.length ;i++){
            uint256 id = vestingIds[i];
            Vesting memory vesting = vestings[account][id];
            if(!_isNull(vesting)) count ++;
                
       }
       Vesting[] memory userVesting = new Vesting[](count);
        uint256 index = 0;
       for(uint256 i = 0;i < vestingIds.length ;i++){
            uint256 id = vestingIds[i];
            Vesting memory vesting = vestings[account][id];
            if( !_isNull(vesting)){
                userVesting[index] = vesting;
                index++;
            }
       }
      return userVesting;
    }
    function _isNull(Vesting memory vesting) internal pure returns(bool){
      return vesting.startTime == 0 && vesting.id == 0;
    }
    
    function immediateConversion(uint256 amount,uint slippage) public nonReentrant payable {
        require(balanceOf(msg.sender) >= amount, "Insufficient xScales balance");

        uint wethAmount = quotePayment(amount);

        require(wethAmount > 0,"error ETH");

        require(msg.value >= wethAmount,"Insufficient ETH");
        uint rate = (msg.value - wethAmount ) * 10000 / wethAmount;
        require(rate <= slippage,"slippage error");

        _burn(msg.sender, amount);
        
        WETH.deposit{value: wethAmount}();

        assert(WETH.transfer(treasury, wethAmount));

        uint _balanceOf = TOKEN.balanceOf(address(this));
        if (_balanceOf < amount) {
            TOKEN.mint(address(this), amount - _balanceOf);
        }
        require(TOKEN.transfer(msg.sender, amount), "Transfer failed");
    }

    function quotePayment(uint256 amount) public view returns(uint) {
      uint256 tokenAmount = amount * (100 - exitRatio) / 100;
     (uint amountout, ) = IRouter(router).getAmountOut(tokenAmount, address(TOKEN),  address(WETH)) ;
     return amountout;
    }

}