// SPDX-License-Identifier: MIT

pragma solidity 0.8.33;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @author Gearhart
 * @notice This library is used to check the Chainlink Oracle for stale data.
 * If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
 * We want the DSCEngine to freeze if prices become stale.
 */
library OracleLib {
    error OracleLib__StalePrice();
    error OracleLib__InvalidPrice();
    error OracleLib__IncompleteRound();

    // heartbeat for these price feeds is 1 hour. Extending to 3 hours to make sure pice is officially stale
    uint256 private constant TIMEOUT = 3 hours; // 3 * 60 * 60 = 10800 seconds

    function stalePriceFeedCheckLatestRoundData(AggregatorV3Interface priceFeed)
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        // NOTE: If deploying to Arbitrum, consider adding a Sequencer Uptime check here.
        // See: https://docs.chain.link/data-feeds/l2-sequencer-feeds
        // Example:
        // AggregatorV3Interface sequencerUptimeFeed = AggregatorV3Interface(SEQUENCER_UPTIME_FEED);
        // (, int256 status, , uint256 sequencerUpdatedAt, ) = sequencerUptimeFeed.latestRoundData();
        // if (status != 0) revert OracleLib__InvalidPrice();
        // if (block.timestamp - sequencerUpdatedAt <= GRACE_PERIOD_TIME) revert OracleLib__InvalidPrice();

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        if (answer <= 0) {
            // ToDo: check error works correctly
            revert OracleLib__InvalidPrice();
        }
        if (answeredInRound < roundId) {
            // ToDo: check error works correctly
            revert OracleLib__IncompleteRound();
        }
        if (updatedAt == 0 || startedAt == 0) {
            // ToDo: check error works correctly
            revert OracleLib__InvalidPrice();
        }

        uint256 secondsSincePriceUpdate = block.timestamp - updatedAt;
        if (secondsSincePriceUpdate > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
