// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol"; /* !UPDATE, import aggregator contract */

contract BettingGame is VRFConsumerBase {
    
  AggregatorV3Interface internal ethUsd; 
    
  uint256 internal fee;
  uint256 public randomResult;
  
  address constant VFRC_address = 0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B; // VRF Coordinator
  address constant LINK_address = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709; // LINK token
  
  uint256 constant half = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
  
  bytes32 constant internal keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
  
  uint256 public gameId;
  uint256 public lastGameId;
  address payable public admin;
  mapping(uint256 => Game) public games;

  struct Game{
    uint256 id;
    uint256 bet;
    uint256 seed;
    uint256 amount;
    address payable player;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin, 'caller is not the admin');
    _;
  }

  modifier onlyVFRC() {
    require(msg.sender == VFRC_address, 'only VFRC can call this function');
    _;
  }
  
  event Withdraw(address admin, uint256 amount);
  event Received(address indexed sender, uint256 amount);
  event Result(uint256 id, uint256 bet, uint256 randomSeed, uint256 amount, address player, uint256 winAmount, uint256 randomResult, uint256 time);
  

  constructor() VRFConsumerBase(VFRC_address, LINK_address) public {
    fee = 0.1 * 10 ** 18; // 0.1 LINK
    admin = msg.sender;
    
    ethUsd = AggregatorV3Interface(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e);
  }
  
  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
  

  function ethInUsd() public view returns (int) {
    (uint80 roundId, int price, uint startedAt, uint timeStamp, uint80 answeredInRound) = ethUsd.latestRoundData();
    
    return price;
  }

  function weiInUsd() public view returns (uint) {
    int _ethUsd = ethInUsd();
    int weiUsd = 10**26/_ethUsd;
    
    return uint(weiUsd);
  }
  
  function game(uint256 bet, uint256 seed) public payable returns (bool) {



    uint weiUsd = weiInUsd();
    require(msg.value>=weiUsd, 'Error, msg.value must be >= $1');
      
    require(bet<=1, 'Error, accept only 0 and 1');

    require(address(this).balance>=msg.value, 'Error, insufficent vault balance');
    
    games[gameId] = Game(gameId, bet, seed, msg.value, msg.sender);
    
    gameId = gameId+1;

    getRandomNumber(seed);
    
    return true;
  }
  
  function getRandomNumber(uint256 userProvidedSeed) internal returns (bytes32 requestId) {
    require(LINK.balanceOf(address(this)) > fee, "Error, not enough LINK - fill contract with faucet");
    return requestRandomness(keyHash, fee, userProvidedSeed);
  }

  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
    randomResult = randomness;

    verdict(randomResult);
  }
  
  function verdict(uint256 random) public payable onlyVFRC {
    for(uint256 i=lastGameId; i<gameId; i++){
      uint256 winAmount = 0;
      
      if((random>=half && games[i].bet==1) || (random<half && games[i].bet==0)){
        winAmount = games[i].amount*2;
        games[i].player.transfer(winAmount);
      }
      emit Result(games[i].id, games[i].bet, games[i].seed, games[i].amount, games[i].player, winAmount, random, block.timestamp);
    }
    lastGameId = gameId;
  }
  
  function withdrawLink(uint256 amount) external onlyAdmin {
    require(LINK.transfer(msg.sender, amount), "Error, unable to transfer");
  }
  
  function withdrawEther(uint256 amount) external payable onlyAdmin {
    require(address(this).balance>=amount, 'Error, contract has insufficent balance');
    admin.transfer(amount);
    
    emit Withdraw(admin, amount);
  }
}