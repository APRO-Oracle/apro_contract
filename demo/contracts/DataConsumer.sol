// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED
 * VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * If you are reading data feeds on L2 networks, you must
 * check the latest answer from the L2 Sequencer Uptime
 * Feed to ensure that the data is accurate in the event
 * of an L2 sequencer outage. See the
 * page for details.
 */

contract DataConsumer {
    AggregatorV3Interface internal dataFeed;

    /**
     * Network: Bitlayer
     * Aggregator: BTC/USD
     * Address: 0xF8F8B81bC86EF4ffc9a46E7d952E65B8eeb7A8e9
     */
    constructor() {
        dataFeed = AggregatorV3Interface(
            0xF8F8B81bC86EF4ffc9a46E7d952E65B8eeb7A8e9
        );
    }

    /**
     * Returns the latest answer.
     */
    function getAproDataFeedLatestAnswer() public view returns (int) {
        // prettier-ignore
        (
        /* uint80 roundID */,
        int answer,
        /*uint startedAt*/,
        /*uint timeStamp*/,
        /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        return answer;
    }

    /**
     * Returns decimals.
     */
    function getDecimals() public view returns (uint8) {
        uint8 decimals = dataFeed.decimals();
        return decimals;
    }
}
