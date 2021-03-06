// contracts/TVL.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155PausableUpgradeable.sol";

import "./TrancheSystem.sol";

/// ---------------------------------------
/// @title An NFT for money market rewards
/// @author Andreas Bigger <bigger@usc.edu>
/// @dev ERC1155 NFTs with Chainlink Oracle
///      Access to allow pool creators to
///      distribute NFT rewards
/// ---------------------------------------

abstract contract TVL is TrancheSystem, ERC1155PausableUpgradeable {
    using SafeMathUpgradeable for uint256;

    // * Adapter Address
    address internal ADAPTER_CONTRACT_ADDRESS;

    // * Event to record rug pulls
    event RugPull(address _from);

    /// @dev mapping from token id to if it exists
    mapping(uint256 => bool) public tokenIdExists;

    /// @dev mapping of amount of tokens per id
    mapping(uint256 => uint256) public numTokensById;

    /// @dev maximum tranche token id, token ids must be created sequentially based on id exists
    uint256 public maxTokenId;

    /// @dev load metadata api and instantiate ownership
    /// @param _owner address of the contract owner
    /// @param _uri base uri for initialization of erc1155
    /// @param _adapter_address address of the pool
    function initialize(
        address _owner,
        string memory _uri,
        address _adapter_address
    ) public virtual initializer {
        ADAPTER_CONTRACT_ADDRESS = _adapter_address;
        __ERC1155_init(_uri);
        __Ownable_init();
        transferOwnership(_owner);
    }

    /// @dev function to mint items, only allowed for devs, external
    /// @param _id token id
    /// @param _amount: number of tokens
    /// @param _uri_data: data to be injected into uri
    /// @return minted id
    function mintItem(
        uint256 _id,
        uint256 _amount,
        bytes calldata _uri_data
    ) external onlyOwner nonReentrant aboveZero(_id) returns (uint256) {
        // * Make sure previous level exists
        uint256 _prevId = _id.sub(1);
        if (_prevId > 0) {
            require(
                tokenIdExists[_prevId] == true,
                "Previous token id must exist."
            );
        }

        // * MINT IT
        _mint(msg.sender, _id, _amount, _uri_data);

        // * Set token id stores
        maxTokenId = _id;
        tokenIdExists[_id] = true;
        numTokensById[_id] = _amount;

        // * Return newly minted token
        return _id;
    }

    /// @dev function to get total amount of tokens over all token ids
    /// @return uint256 number of total tokens
    function getTotalNumberTokens() external view returns (uint256) {
        uint256 totalNum = 0;
        for (uint256 i = 0; i < maxTokenId; i++) {
            totalNum = totalNum.add(numTokensById[i]);
        }
        return totalNum;
    }

    /// @dev overriden function from ERC1155Upgradeable.sol to regulate token transfers
    /// @param operator token id
    /// @param from address transferring
    /// @param to receiving address
    /// @param data token id data
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        // * Get current user tranche level
        uint256 user_level = address_to_tranche[from];

        // * Get current user tranche from level
        Tranche memory user_tranche = tranche_map[user_level];

        // * Get which ids are available to user
        uint256[] memory user_ids = user_tranche.ids;

        for (uint256 id = 0; id < user_ids.length; id++) {
            uint256 max_amount = tranche_id_amounts[user_level][user_ids[id]];
            // * Calculate amount user can withdraw as % of pool TVL
            uint256 max_allowed = getPoolShare(from, max_amount);
            require(
                amounts[id] < max_allowed,
                "Id amounts must be less than the allowed tranche amounts."
            );
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /// @notice Must be implemented by children
    /// @dev function to get the amount of pool share the user has
    /// @param _from address of the current user
    /// @param _max_amount the amount of a given token id
    /// @return uint256 amount of tokens to give to the user
    function getPoolShare(address _from, uint256 _max_amount)
        public
        virtual
        returns (uint256);

    /// @dev function to redeem tokens
    /// @param _ids tranche level
    /// @param _data data for batch transfer
    /// @return bool if successful
    function redeem(uint256[] calldata _ids, bytes calldata _data)
        external
        aboveZeroArray(_ids)
        whenNotPaused()
        returns (bool)
    {
        bool successful = true;

        // * Get current user tranche level
        uint256 user_level = address_to_tranche[msg.sender];

        // * Get which ids are available to user
        uint256[] memory user_ids = tranche_map[user_level].ids;

        // * Batch transfer array
        uint256[] memory batch_ids = new uint256[](user_ids.length);
        uint256[] memory batch_amounts = new uint256[](user_ids.length);

        uint256 counter = 0;
        // * Iterate over tranche ids and redeem the ones in the input array
        for (uint256 i = 0; i < user_ids.length; i++) {
            uint256 user_id = user_ids[i];
            for (uint256 x = 0; x < _ids.length; x++) {
                if (user_id == _ids[x]) {
                    // * If this is an id to redeem, append to amounts for batch transfer
                    batch_ids[counter] = user_id;
                    batch_amounts[counter] = tranche_id_amounts[user_level][
                        user_id
                    ];
                    counter++;
                }
            }
        }

        // * Batch transfer
        safeBatchTransferFrom(
            owner(),
            msg.sender,
            batch_ids,
            batch_amounts,
            _data
        );

        // * Emit redemption event
        emit TokenRedemption(batch_ids, _data);

        // * Returns if successful
        return successful;
    }

    /// @dev function set approval for redemption
    /// @param _user user's address
    /// @param _approved whether the user is approved to transfer or not
    function setApproval(address _user, bool _approved) external onlyOwner {
        // * Set approval
        setApprovalForAll(_user, _approved);
    }

    /// --------------------------------------------------------
    ///    Pausible Function Implementations
    /// --------------------------------------------------------

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() public whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() public whenPaused onlyOwner {
        _unpause();
    }

    /// @dev disables any token flow by pausing the contract and claws back any to contract owner
    function rugPull() external onlyOwner {
        // * Pause the contract and all token transfers
        pause();

        // * Claw back all tokens
        _claw();

        // * Emit event
        emit RugPull(msg.sender);
    }

    // @dev internal function to claw back all tokens to specific admin address
    function _claw() public onlyOwner {
        // TODO: Implement
    }
}
