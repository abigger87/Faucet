// contracts/interfaces/IRariFundManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/// ---------------------------------------
/// @title Generic Faucet Adapter
/// @dev interface to define pool adapters
///      for Faucet.sol
/// ---------------------------------------
contract IAdapter {
    /**
     * @notice Returns the pool's total investor balance
     */
    function getEntireBalance() public returns (uint256) {}

    /// @dev Allow owner to get the current pool address
    /// @return address of new pool
    function get_pool_address() external view returns (address) {}

    /// @dev function to get the amount of pool share by a user
    /// @param _from address of the current user
    /// @param _max_amount the amount of a given token id
    /// @return uint256 amount of tokens to give to the user
    function get_pool_share(address _from, uint256 _max_amount)
        public
        returns (uint256)
    {}

    /// @dev Allow owner to set pool address to avoid unnecessary upgrades
    /// @param _pool_address address of the pool
    /// @return address of new pool
    function set_pool_address(address _pool_address)
        external
        returns (address)
    {}

    /**
     * @notice Returns an account's total balance in ETH (convertable inside an adapter).
     * @param account The account whose balance we are calculating.
     */
    function balanceOf(address account) external returns (uint256) {}
}
