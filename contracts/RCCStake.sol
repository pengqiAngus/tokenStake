// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RCCStack is Initializable,UUPSUpgradeable,AccessControlUpgradeable,PausableUpgradeable{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");
    uint256 public constant nativeCurrency_PID = 0;

    struct Pool{
        address stTokenAddress; // 质押代币的地址
        uint256 poolWeight; // 质押池的权重，影响奖励分配
        uint256 lastRewardBlock; //最后一次计算奖励的区块号
        uint256 accRCCPerSt; //每个质押代币累积可领取的 RCC 数量 1个质押代币可以换几个RCC
        uint256 stTokenAmount; //池中的总质押代币量
        uint256 minDepositAmount; ///最小质押金额
        uint256 unstakeLockedBlocks; //解除质押的锁定区块数
    }
    struct UnstakeRequest{
        uint256 amount; //解除质押代币的数量
        uint256 unlockBlocks; //解除质押的锁定区块数
    }

    struct User{
        uint256 stAmount;//用户质押的代币数量
        uint256 finishedRCC; //  已分配的 RCC 数量
        uint256 pendingRCC; // 待领取的 RCC 数量
        UnstakeRequest[] request; //  解质押请求列表，每个请求包含解质押数量和解锁区块
    }
    uint256 public startBlock; //Rcc质押的开始区块
    uint256 public  endBlock; //Rcc质押的结束区块
    uint256 public RCCPerBlock; // 每个区块的RCCtoken奖励
    bool public widthdrawPaused; // 暂停取钱
    bool public claimPaused; // 暂停取钱
    IERC20 public RCC;
    uint256 public  totalPoolWeight;  // Total pool weight / Sum of all pool weights
    Pool[] public pool;
    mapping (uint256=>mapping (address=>User)) public user;  // pool id => user address => user info

    event SetRCC(IERC20 indexed RCC);
    event PauseWithdraw();
    event UnpauseWidthdraw();
    event PauseClaim();
    event UnPauseClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetendBlock(uint256 indexed endBlock);
    event SetRCCPerBlock(uint256 indexed RCCPerBlock);
    event AddPool(address indexed stTokenAddress, uint256 indexed poolWeight, uint256 indexed lastRewardBlock, uint256 minDepositAmount, uint256 unstakeLockedBlocks);
    event UpdatePoolInfo(uint256 indexed poolId, uint256 indexed minDepositAmount, uint256 indexed unstakeLockedBlocks );
    event SetPoolWeight(uint256 indexed  poolId, uint256 indexed  poolweight, uint256 totalPoolWeight);
    event UpdatePool(uint256 indexed  poolId, uint256 indexed lastRewardBlock, uint256 totalRCC);
    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed poolId, uint256 amount);
    event Withdraw(address indexed  uuser, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber );
    event Claim(address indexed user, uint256 indexed poolId, uint256 RCCReward);

    modifier checkPid(uint256 _pid){
        require(_pid <pool.length, "invalid pid");
        _;
    }

    modifier  whenNotClaimPaused(){
        require(!claimPaused,"claim is pasuesed");
        _;
    }
     modifier  whenNotWithdrawPaused(){
        require(!widthdrawPaused,"claim is pasuesed");
        _;
    }

    function initialize(IERC20 _RCC, uint256 _startBlock, uint256 _endBlock, uint256 _RCCPerBlock ) public initializer {
        require(_startBlock <= _endBlock && _RCCPerBlock > 0, "invalid parameters");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        setRCC(_RCC);
        
        startBlock = _startBlock;
        endBlock = _endBlock;
        RCCPerBlock = _RCCPerBlock;
    }

    function _authorizeUpgrade(address newImplementation) internal  onlyRole(UPGRADE_ROLE) override  {
        
    }

    function setRCC(IERC20 _RCC) public  onlyRole(ADMIN_ROLE){
        RCC = _RCC;
        emit SetRCC(RCC);
    }

    function pauseWithdraw() public  onlyRole(ADMIN_ROLE){
        require(!widthdrawPaused, "withdraw has been alreay pasuesd");
        widthdrawPaused = true;
        emit PauseWithdraw();
    }
    function unPauseWithdraw() public  onlyRole(ADMIN_ROLE){
        require(widthdrawPaused, "withdraw has been alreay pasuesd");
        widthdrawPaused = false;
        emit UnpauseWidthdraw();
    }
    function pauseClaim() public  onlyRole(ADMIN_ROLE){
        require(!claimPaused, "withdraw has been alreay pasuesd");
        claimPaused = true;
        emit PauseClaim();
    }
    function unPauseClaim() public  onlyRole(ADMIN_ROLE){
        require(claimPaused, "withdraw has been alreay pasuesd");
        claimPaused = false;
        emit UnPauseClaim();
    }
    // 每个区块的RCCtoken奖励
    function setStartBlock(uint256 _startBlock) public onlyRole(ADMIN_ROLE){
        require(_startBlock < endBlock,"start block must be smaller than end block");
        startBlock =_startBlock;
        emit SetStartBlock(_startBlock);
    }
    function setEndBlock(uint256 _endBlock) public onlyRole(ADMIN_ROLE){
        require(startBlock < _endBlock,"start block must be smaller than end block");
        endBlock =_endBlock;
        emit SetStartBlock(_endBlock);
    }
    function setRCCPerBlock(uint256 _RCCPerBlock) public onlyRole(ADMIN_ROLE) {
        require(_RCCPerBlock > 0, "invalid parameter");
        RCCPerBlock =_RCCPerBlock;
        emit SetRCCPerBlock(_RCCPerBlock);
    }
    function addPoll(address _stTokenAddress, uint _poolWeight, uint256 _minDepositAmount, uint256 unstakeLockedBlocks, bool _withUpdate)  public onlyRole(ADMIN_ROLE) {
        if (pool.length > 0 ) {
            require(_stTokenAddress != address(0), "invalid staking token address");
        }else {
            require(_stTokenAddress == address(0), "invalid staking token address");
        }
        require(_minDepositAmount>0,"invalid min deposit amount");
        require(unstakeLockedBlocks>0, "invalid withdraw locked blocks");
        require(block.number < endBlock, "Already ended");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number: startBlock;
        totalPoolWeight +=_poolWeight;
        pool.push(Pool({
            stTokenAddress: _stTokenAddress,
            poolWeight:_poolWeight,
            lastRewardBlock : lastRewardBlock,
            accRCCPerSt:0,
            stTokenAmount: 0,
            minDepositAmount:_minDepositAmount,
            unstakeLockedBlocks: unstakeLockedBlocks
        }));
        emit AddPool(_stTokenAddress, _poolWeight, lastRewardBlock, _minDepositAmount, unstakeLockedBlocks);
    }
    function updatePoolInfo(uint256 _pid, uint256 _minDepositAmount, uint256 _unstakeLockedBlocks) public onlyRole(ADMIN_ROLE){
        pool[_pid].minDepositAmount =_minDepositAmount;
        pool[_pid].unstakeLockedBlocks =_unstakeLockedBlocks;
        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }
    function setPoolWeight(uint256 _pid,uint _poolWeight,bool _withUpdate) public onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(_poolWeight>0, "invalid pool weight");
        if(_withUpdate){
             massUpdatePools();
        }
        totalPoolWeight = totalPoolWeight-pool[_pid].poolWeight +_poolWeight;
        pool[_pid].poolWeight =_poolWeight;
    }

    function poolLength() external view returns(uint256) {
        return pool.length;
    }

    // 得到区块区间内所有RCC奖励的总和
    function getMultiplier(uint256 _from, uint256 _to) public view returns( uint256 ) {
        require(_from <= _to, "invalid block range");
        if (_from < startBlock) {_from = startBlock;}
        if (_to > endBlock) {_to = endBlock;}
        require(_from <= _to, "invalid block range");
        (bool success, uint256 multiplier ) = (_to - _from).tryMul(RCCPerBlock);
        require(success, "multiplier overflow");
        return  multiplier;
    }

    function pendingRCC(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return pendingRCCByBlockNumber(_pid, _user, block.number);
    }
    function pendingRCCByBlockNumber(uint256 _pid, address _user, uint256 _blockNumber  )public  checkPid(_pid) view returns(uint256) {
        Pool storage pool_ =pool[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accRCCPerSt = pool_.accRCCPerSt; //池子中RCC的数量
        uint256 stSupply = pool_.stTokenAmount; //池子中质押代币的数量
        if(_blockNumber > pool_.lastRewardBlock && stSupply !=0){
            uint256 multiplier = getMultiplier( pool_.lastRewardBlock, _blockNumber); //所有池子在 所选区块区间的RCC奖励 总数量
            uint256 RCCForPool = multiplier * pool_.poolWeight/totalPoolWeight;//当前池子在 所选区块区间的RCC奖励 总数量
            accRCCPerSt = accRCCPerSt + RCCForPool*(1 ether) /stSupply; // 当前池子 RCC总数量 / 质押代币的总数量 = 每个质押代币兑换多少RCC (最后再加上原来可以兑换多少个=现在可以兑换多少个)
        }
        return user_.stAmount * accRCCPerSt / (1 ether) - user_.finishedRCC + user_.pendingRCC;// 用户质押了多少代币数去 乘以 兑换比例的 等于 可以兑换多少个RCC数（最后减去已经兑换了的数量和还没有兑换的数量 = 可以兑换的数量）
    }
    function stakingBalance(uint256 _pid, address _user) external checkPid(_pid) view returns(uint256) {
        return user[_pid][_user].stAmount;
    }

    function withdrawAmount(uint256 _pid, address _user) public checkPid(_pid) view returns(uint256 reuqestAmount, uint256 pendingWithdrawAmount) {
        User storage user_ = user[_pid][_user];
        for (uint256 i = 0; i < user_.request.length; i++) {
            if(user_.request[i].unlockBlocks <= block.number){
                pendingWithdrawAmount += user_.request[i].amount;
            } else {
                reuqestAmount += user_.request[i].amount;
            }
        }
    }

    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        if (block.number < pool_.lastRewardBlock) {
            return;
        }
        uint256 totalRCC = getMultiplier(pool_.lastRewardBlock, block.number );
        (bool success2, uint256 totalRCC2) = totalRCC.tryDiv(totalPoolWeight);
        require(success2, "totalRCC div totalPoolWeight overflow");
        uint256 stSupply = pool_.stTokenAmount;
        if(stSupply > 0){
            (bool success3, uint256 totalRCC3)= totalRCC2.tryMul(1 ether);
            require(success3 ,"totalRCC mul 1 ether overflow");
            (bool success4, uint256 totalRCC4) = totalRCC3.tryDiv(stSupply);
            require(success4, "totalRCC div stSupply overflow");
            (bool success5, uint256 accRCCPerSt) = pool_.accRCCPerSt.tryAdd(totalRCC4);
            require(success5, "pool accRCCPerST overflow");
            pool_.accRCCPerSt = accRCCPerSt;
        }
        pool_.lastRewardBlock = block.number;
        emit UpdatePool(_pid, pool_.lastRewardBlock, totalRCC);
    }

    function massUpdatePools() public {
        uint256 length = pool.length;
        for (uint i = 0; i < length; i++) {
            updatePool(i);
        }
    }

    function dedpositNativeCurrency() public whenNotPaused() payable{
        Pool storage pool_ = pool[nativeCurrency_PID];
        require(pool_.stTokenAddress == address(0),"invalid staking token address");
        uint256 _amount =msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");
        _deposit(nativeCurrency_PID,_amount);
    }

    function deposit(uint256 _pid) public whenNotPaused() checkPid(_pid) payable{
        require(_pid != nativeCurrency_PID,"invalid staking token address");
        Pool storage pool_ = pool[_pid];
        uint256 _amount =msg.value;
        require(_amount >= pool_.minDepositAmount, "deposit amount is too small");
        IERC20(pool_.stTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        _deposit(nativeCurrency_PID,_amount);
    }

    function unstake(uint256 _pid, uint256 _amount) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused() {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        require(user_.stAmount >= _amount, "Not enough staking token balance");
        updatePool(_pid);
        uint256 pendingRCC_ = user_.stAmount * pool_.accRCCPerSt / (1 ether) - user_.finishedRCC;
        if(pendingRCC_ >0){
            user_.pendingRCC = user_.pendingRCC + pendingRCC_;
        }
        if(_amount>0){
            user_.stAmount  -= _amount;
            user_.request.push(UnstakeRequest({
                amount: _amount,
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            }));
        }
        pool_.stTokenAmount -=_amount;
        user_.finishedRCC = user_.stAmount* pool_.accRCCPerSt /(1 ether);
        emit RequestUnstake(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid) public whenNotPaused() checkPid(_pid) whenNotWithdrawPaused()   {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        uint256 pendingWithdraw_;
        uint256 popNum_;
        for (uint i = 0; i < user_.request.length; i++) {
            if (user_.request[i].unlockBlocks < block.number) {
                break;
            }
            pendingWithdraw_ = pendingWithdraw_ + user_.request[i].amount;
            popNum_++;
        }
        for (uint i = 0; i < user_.request.length-popNum_; i++) {
            user_.request[i] = user_.request[i+popNum_];
        }
        for (uint i = 0; i < popNum_; i++) {
            user_.request.pop();

        }
        if (pendingWithdraw_ > 0) {
            if(pool_.stTokenAddress == address(0)){
                _safenativeCurrencyTransfer(msg.sender, pendingWithdraw_);
            }else{
                IERC20(pool_.stTokenAddress).safeTransfer(msg.sender,pendingWithdraw_);
            }
        }
        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }
    function claim(uint256 _pid) whenNotPaused() public  checkPid(_pid) whenNotClaimPaused()  {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        updatePool(_pid);
        uint256 pendingRCC_ = user_.stAmount * pool_.accRCCPerSt / (1 ether) - user_.finishedRCC + user_.pendingRCC;
        if (pendingRCC_>0) {
             user_.pendingRCC = 0;
            _safeRCCTransfer(msg.sender, pendingRCC_);
        }
        user_.finishedRCC = user_.stAmount * pool_.accRCCPerSt / (1 ether);
        emit Claim(msg.sender, _pid, pendingRCC_);
    }
    function _deposit(uint256 _pid, uint256 _amount) internal{
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];
        if (user_.stAmount>0) {
            (bool success1, uint256 accST) = user_.stAmount.tryMul(pool_.accRCCPerSt);
            require(success1, "user stAmount mul accRCCPerST overflow");
            (success1, accST) = accST.tryDiv(1 ether);
            require(success1, "accST div 1 ether overflow");
            (bool success2, uint256 pendingRCC_) = accST.trySub(user_.finishedRCC);
            require(success2, "accST sub finishedRCC overflow");
            if(pendingRCC_>0){
                (bool success3, uint256 _pendingRCC) = user_.pendingRCC.tryAdd(pendingRCC_);
                require(success3, "user pendingRCC overflow");
                user_.pendingRCC = _pendingRCC;
            }
        }
        if (_amount > 0 ) {
            (bool success4, uint256 stAmount) = user_.stAmount.tryAdd(_amount);
            require(success4, "user stAmount overflow");
            user_.stAmount = stAmount;
        }
        (bool success5, uint256 stTokenAmount) = pool_.stTokenAmount.tryAdd(_amount);
        require(success5, "pool stTokenAmount overflow");
        pool_.stTokenAmount = stTokenAmount;

        // (bool success6, uint256 finishedRCC) = user_.stAmount.tryMul(pool_.accRCCPerSt);
        // require(success6, "user stAmount mul accRCCPerST overflow");
        // (success6, finishedRCC) = finishedRCC.tryDiv(1 ether);
        // require(success6, "finishedRCC div 1 ether overflow");

        // user_.finishedRCC = finishedRCC;

        emit Deposit(msg.sender, _pid, _amount);
    }
    function _safeRCCTransfer(address _to, uint256 _amount) internal{
        uint256 RCCBal = RCC.balanceOf(address(this));
        if (_amount > RCCBal) {
            RCC.transfer(_to, RCCBal);
        }else {
            RCC.transfer(_to, _amount);
        }
    }

    function _safenativeCurrencyTransfer(address _to, uint256 _amount)internal{
        (bool success, bytes memory data) = address(_to).call{value:_amount}("");
        require(success, "nativeCurrency transfer call failed");
        if (data.length > 0) {
            require(abi.decode(data, (bool)),"nativeCurrency transfer operation did not succeed");
        }
    }
}