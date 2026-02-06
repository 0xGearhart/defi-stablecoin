// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockV3AggregatorWithAnsweredInRound {
    uint8 public decimals;
    int256 public latestAnswer;
    uint256 public latestTimestamp;
    uint256 public latestRound;
    uint80 public latestAnsweredInRound;
    uint256 private latestStartedAt;

    constructor(uint8 _decimals, int256 _initialAnswer, uint80 _answeredInRound) {
        decimals = _decimals;
        updateRoundData(1, _initialAnswer, block.timestamp, block.timestamp, _answeredInRound);
    }

    function updateRoundData(
        uint80 _roundId,
        int256 _answer,
        uint256 _timestamp,
        uint256 _startedAt,
        uint80 _answeredInRound
    )
        public
    {
        latestRound = _roundId;
        latestAnswer = _answer;
        latestTimestamp = _timestamp;
        latestStartedAt = _startedAt;
        latestAnsweredInRound = _answeredInRound;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            uint80(latestRound),
            latestAnswer,
            latestStartedAt,
            latestTimestamp,
            latestAnsweredInRound
        );
    }
}
