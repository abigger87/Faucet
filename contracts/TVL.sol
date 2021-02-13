// contracts/TVL.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./v0.6/ChainlinkClient.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// ---------------------------------------
/// @title An NFT for money market rewards
/// @author Andreas Bigger <bigger@usc.edu>
/// @dev ERC1155 NFTs with Chainlink Oracle
///      Access to allow pool creators to
///      distribute NFT rewards
/// ---------------------------------------
contract TVL is ERC1155, ChainlinkClient {
    using SafeMathUpgradeable for uint256;

    /// @dev Chainlink Oracle Logic Here
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    uint256 public pool_tvl;

    /// @dev Define metadata api and chainlink initialization
    constructor() public ERC1155("https://game.example/api/item/{id}.json") {
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10**18; // 0.1 LINK
    }

    modifier onlyOwner() {
        require(msg.sender == owner());
        _;
    }

    /// @dev function to mint items, only allowed for devs, external
    /// @param uint256
    /// @param uint256
    /// @param butes
    /// @return uint256
    function mint_item(
        uint256 id,
        uint256 amount,
        bytes data
    ) external onlyOwner returns (uint256) {
        _mint(msg.sender, id, amount, data);
        return id;
    }

    /// @notice Create a Chainlink request to retrieve API response, find the target
    ///         data, then multiply by 1000000000000000000 (to remove decimal places from data).
    function requestTVLData() public returns (bytes32 requestId) {
        Chainlink.Request memory request =
            buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        request.add(
            "get",
            "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=ETH&tsyms=USD"
        );

        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"ETH":
        //    {"USD":
        //     {
        //      "VOLUME24HOUR": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        request.add("path", "RAW.ETH.USD.VOLUME24HOUR");

        // * Multiply the result by 1000000000000000000 to remove decimals
        int256 timesAmount = 10**18;
        request.addInt("times", timesAmount);

        // * Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    /// @notice Receive the response in the form of uint256
    function fulfill(bytes32 _requestId, uint256 _tvl)
        public
        recordChainlinkFulfillment(_requestId)
    {
        pool_tvl = _tvl;
    }
}
