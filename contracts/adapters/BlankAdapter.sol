// contracts/TVL.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

/// ---------------------------------------
/// @title Empty Faucet Adapter
/// @author Andreas Bigger <bigger@usc.edu>
/// @dev ERC1155 NFTs to unlock rewards based on pool TVL
/// ---------------------------------------
contract BlankAdapter is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    modifier aboveZero(uint256 _x) {
        require(_x > 0, "Input must be greater than zero.");
        _;
    }

    // * Default pool address
    address private POOL_ADDRESS;

    /// @dev load metadata api and fetch eth_pool balance
    /// @param _owner address of the contract owner
    /// @param _pool_address address of the pool
    function initialize(address _owner, address _pool_address)
        public
        initializer
    {
        POOL_ADDRESS = _pool_address;
        __Ownable_init();
        transferOwnership(_owner);
    }

    /// @dev Allow owner to get the current pool address
    /// @return address of new pool
    function get_pool_address() external view onlyOwner returns (address) {
        return POOL_ADDRESS;
    }

    /// @dev Allow owner to set pool address to avoid unnecessary upgrades
    /// @param _pool_address address of the pool
    /// @return address of new pool
    function set_pool_address(address _pool_address)
        external
        onlyOwner
        returns (address)
    {
        require(_pool_address != address(0), "Must be a valid address");
        POOL_ADDRESS = _pool_address;
        return _pool_address;
    }

    /// @dev function to get the amount of pool share by a user
    /// @param _from address of the current user
    /// @param _max_amount the amount of a given token id
    /// @return uint256 amount of tokens to give to the user
    function get_pool_share(address _from, uint256 _max_amount)
        public
        aboveZero(_max_amount)
        returns (uint256)
    {
        // TODO: Dynamically fetch fund_balance and user_balance
        uint256 fund_balance = 1000;
        uint256 user_balance = 10;
        uint256 percent = _percent(user_balance, fund_balance, 3);

        return _percent(_max_amount * percent, 1000, 2);
    }

    /// @dev helper function to get percent
    /// @param _numerator fraction numerator
    /// @param _denominator fraction denominator
    /// @param _precision precision of numerator in calculation
    /// @return uint256 percent * 10
    function _percent(
        uint256 _numerator,
        uint256 _denominator,
        uint256 _precision
    ) internal pure returns (uint256) {
        // caution, check safe-to-multiply here
        uint256 _multiplied_numerator = _numerator * 10**(_precision + 1);
        // with rounding of last digit
        uint256 _quotient = ((_multiplied_numerator / _denominator) + 5) / 10;
        return (_quotient);
    }
}
