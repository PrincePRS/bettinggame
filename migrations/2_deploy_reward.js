const Betting = artifacts.require("BettingGame");

module.exports = function (deployer) {
  // deployer.deploy(Reward, 10000000);
  deployer.deploy(Betting);
};
