// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

/**
 * @title The Owned contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract Owned {
    address public owner;
    address private pendingOwner;

    event OwnershipTransferRequested(address indexed from, address indexed to);
    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Allows an owner to begin transferring ownership to a new address,
     * pending.
     */
    function transferOwnership(address _to) external onlyOwner {
        pendingOwner = _to;

        emit OwnershipTransferRequested(owner, _to);
    }

    /**
     * @dev Allows an ownership transfer to be completed by the recipient.
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "Must be proposed owner");

        address oldOwner = owner;
        owner = msg.sender;
        pendingOwner = address(0);

        emit OwnershipTransferred(oldOwner, msg.sender);
    }

    /**
     * @dev Reverts if called by anyone other than the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only callable by owner");
        _;
    }
}

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    event AnswerUpdated(
        int256 indexed current,
        uint256 indexed roundId,
        uint256 updatedAt
    );
    event NewRound(
        uint256 indexed roundId,
        address indexed startedBy,
        uint256 startedAt
    );
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface AggregatorV2V3Interface is
    AggregatorInterface,
    AggregatorV3Interface
{}

interface AggregatorCombineInterface is AggregatorV2V3Interface {
    
    // getCombineRoundData and latestCombineRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getCombineRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            int256 answerX,
            int256 answerY,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestCombineRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            int256 answerX,
            int256 answerY,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title External Access Controlled Aggregator Proxy
 * @notice A trusted proxy for updating where current answers are read from
 * @notice This contract provides a consistent address for the
 * Aggregator and AggregatorV3Interface but delegates where it reads from to the owner, who is
 * trusted to update it.
 * @notice Only access enabled addresses are allowed to access getters for
 * aggregated answers and round information.
 */
contract AggregatorCombineProxy is AggregatorCombineInterface, Owned {
    struct Phase {
        uint16 id;
        AggregatorV2V3Interface aggregatorX;
        AggregatorV2V3Interface aggregatorY;
    }

    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    Phase private currentPhase;
    AggregatorV2V3Interface public proposedAggregatorX;
    AggregatorV2V3Interface public proposedAggregatorY;
    uint8 public override decimals;
    string public override description;

    mapping(uint16 => Phase) public phaseAggregators;

    uint256 private constant PHASE_OFFSET = 64;
    uint256 private constant PHASE_OFFSET_AGGREGATORX = 32;
    uint256 private constant PHASE_SIZE = 16;
    uint256 private constant MAX_ID = 2 ** (PHASE_OFFSET + PHASE_SIZE) - 1;


    constructor(
        address _aggregatorX,
        address _aggregatorY,
        uint8 _decimals,
        string memory _description
    ) Owned() {
        setAggregators(_aggregatorX, _aggregatorY);
        decimals = _decimals;
        description = _description;
    }

    /**
     * @notice Reads the current answer from aggregator delegated to.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestAnswer()
        public
        view
        virtual
        override
        returns (int256 answer)
    {
        int256 answerX = currentPhase.aggregatorX.latestAnswer();
        int256 answerY = currentPhase.aggregatorY.latestAnswer();
        uint8 decimalsX = currentPhase.aggregatorX.decimals();
        uint8 decimalsY = currentPhase.aggregatorY.decimals();
        return calcAnswer(answerX, answerY, decimalsX, decimalsY);
    }

    /**
     * @notice Reads the last updated height from aggregator delegated to.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestTimestamp()
        public
        view
        virtual
        override
        returns (uint256 updatedAt)
    {
        uint256 timestampX = currentPhase.aggregatorX.latestTimestamp();
        uint256 timestampY = currentPhase.aggregatorY.latestTimestamp();
        return timestampX > timestampY ? timestampX : timestampY;
    }

    /**
     * @notice get past rounds answers
     * @param _roundId the answer number to retrieve the answer for
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getAnswer(
        uint256 _roundId
    ) public view virtual override returns (int256 answer) {
        if (_roundId > MAX_ID) return 0;

        (
            uint16 id,
            uint64 aggregatorRoundIdX,
            uint64 aggregatorRoundIdY
        ) = parseIds(_roundId);
        AggregatorV2V3Interface _aggregatorX = phaseAggregators[id]
            .aggregatorX;
        AggregatorV2V3Interface _aggregatorY = phaseAggregators[id]
            .aggregatorY;

        if (
            address(_aggregatorX) == address(0) ||
            address(_aggregatorY) == address(0)
        ) return 0;

        int256 answerX = _aggregatorX.getAnswer(aggregatorRoundIdX);
        int256 answerY = _aggregatorY.getAnswer(aggregatorRoundIdY);
        uint8 decimalsX = _aggregatorX.decimals();
        uint8 decimalsY = _aggregatorY.decimals();

        return calcAnswer(answerX, answerY, decimalsX, decimalsY);
    }

    /**
     * @notice get block timestamp when an answer was last updated
     * @param _roundId the answer number to retrieve the updated timestamp for
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getTimestamp(
        uint256 _roundId
    ) public view virtual override returns (uint256 updatedAt) {
        if (_roundId > MAX_ID) return 0;

        (
            uint16 id,
            uint32 aggregatorRoundIdX,
            uint32 aggregatorRoundIdY
        ) = parseIds(_roundId);

        AggregatorV2V3Interface _aggregatorX = phaseAggregators[id]
            .aggregatorX;
        AggregatorV2V3Interface _aggregatorY = phaseAggregators[id]
            .aggregatorY;

        if (
            address(_aggregatorX) == address(0) ||
            address(_aggregatorY) == address(0)
        ) return 0;

        uint256 timestampX = _aggregatorX.getTimestamp(aggregatorRoundIdX);
        uint256 timestampY = _aggregatorY.getTimestamp(aggregatorRoundIdY);

        return timestampX > timestampY ? timestampX : timestampY;
    }

    /**
     * @notice get the latest completed round where the answer was updated. This
     * ID includes the proxy's phase, to make sure round IDs increase even when
     * switching to a newly deployed aggregator.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestRound()
        public
        view
        virtual
        override
        returns (uint256 roundId)
    {
        Phase memory phase = currentPhase;
        return
            addPhase(
                phase.id,
                uint64(phase.aggregatorX.latestRound()),
                uint64(phase.aggregatorY.latestRound())
            );
    }

    /**
     * @notice get data about a round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @param _roundId the requested round ID as presented through the proxy, this
     * is made up of the aggregator's round ID with the phase ID encoded in the
     * two highest order bytes
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function getRoundData(
        uint80 _roundId
    )
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            uint16 id,
            uint32 aggregatorRoundIdX,
            uint32 aggregatorRoundIdY
        ) = parseIds(_roundId);

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = phaseAggregators[id].aggregatorX.getRoundData(aggregatorRoundIdX);

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = phaseAggregators[id].aggregatorY.getRoundData(aggregatorRoundIdY);

        answer = calcAnswer(x.answer, y.answer, phaseAggregators[id].aggregatorX.decimals(), phaseAggregators[id].aggregatorY.decimals());
        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );

        return addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            id
        );
    }

    /**
     * @notice get data about the latest round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with an phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function latestRoundData()
        public
        view
        virtual
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {

        Phase memory current = currentPhase;

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = current.aggregatorX.latestRoundData();

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = current.aggregatorY.latestRoundData();

        answer = calcAnswer(x.answer, y.answer, current.aggregatorX.decimals(), current.aggregatorY.decimals());
        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );

        return addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            current.id
        );
    }

    function getCombineRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            int256 answerX,
            int256 answerY,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            uint16 id,
            uint32 aggregatorRoundIdX,
            uint32 aggregatorRoundIdY
        ) = parseIds(_roundId);

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = phaseAggregators[id].aggregatorX.getRoundData(aggregatorRoundIdX);

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = phaseAggregators[id].aggregatorY.getRoundData(aggregatorRoundIdY);

        answer = calcAnswer(x.answer, y.answer, phaseAggregators[id].aggregatorX.decimals(), phaseAggregators[id].aggregatorY.decimals());
        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );


        RoundData memory z;

        (z.roundId, z.answer, z.startedAt, z.updatedAt, z.answeredInRound) = addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            id
        );

        return (
            z.roundId,
            z.answer,
            x.answer,
            y.answer,
            z.startedAt,
            z.updatedAt,
            z.answeredInRound
        );
    }

    function latestCombineRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            int256 answerX,
            int256 answerY,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Phase memory current = currentPhase;

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = current.aggregatorX.latestRoundData();

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = current.aggregatorY.latestRoundData();

        answer = calcAnswer(x.answer, y.answer, current.aggregatorX.decimals(), current.aggregatorY.decimals());
        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );

        (roundId, answer, startedAt, updatedAt, answeredInRound) = addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            current.id
        );

        return (
            roundId,
            answer,
            x.answer,
            y.answer,
            startedAt,
            updatedAt,
            answeredInRound
        );
    }

    function calcAnswer(
        int256 answerX,
        int256 answerY,
        uint8 decimalsX,
        uint8 decimalsY
    ) internal view returns (int256 answer) {
        return
            (answerX * answerY * int256(10 ** decimals)) /
            int256(10 ** (decimalsX + decimalsY));
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedGetRoundData(
        uint80 _roundId
    )
        public
        view
        virtual
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (
            uint16 id,
            uint32 aggregatorRoundIdX,
            uint32 aggregatorRoundIdY
        ) = parseIds(_roundId);

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = proposedAggregatorX.getRoundData(aggregatorRoundIdX);

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = proposedAggregatorY.getRoundData(aggregatorRoundIdY);

        answer = calcAnswer(x.answer, y.answer, proposedAggregatorX.decimals(), proposedAggregatorY.decimals());
        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );

        return addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            id
        );
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedLatestRoundData()
        public
        view
        virtual
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        Phase memory current = currentPhase;

        RoundData memory x;
        RoundData memory y;

        (
            x.roundId,
            x.answer,
            x.startedAt,
            x.updatedAt,
            x.answeredInRound
        ) = proposedAggregatorX.latestRoundData();

        (
            y.roundId,
            y.answer,
            y.startedAt,
            y.updatedAt,
            y.answeredInRound
        ) = proposedAggregatorY.latestRoundData();

        answer = calcAnswer(x.answer, y.answer, proposedAggregatorX.decimals(), proposedAggregatorY.decimals());

        (startedAt, updatedAt) = determineTimestamp(
            x.startedAt,
            y.startedAt,
            x.updatedAt,
            y.updatedAt
        );

        return addPhaseIds(
            x.roundId,
            y.roundId,
            answer,
            startedAt,
            updatedAt,
            x.answeredInRound,
            y.answeredInRound,
            current.id
        );
    }

    /**
     * @notice returns the current phase's aggregatorX address.
     */
    function aggregatorX() external view returns (address) {
        return address(currentPhase.aggregatorX);
    }

    /**
     * @notice returns the current phase's aggregatorY address.
     */
    function aggregatorY() external view returns (address) {
        return address(currentPhase.aggregatorY);
    }

    /**
     * @notice returns the current phase's aggregatorX' decimals.
     */
    function aggregatorXDecimals() external view returns (uint8) {
        return currentPhase.aggregatorX.decimals();
    }

    /**
     * @notice returns the current phase's aggregatorY' decimals.
     */
    function aggregatorYDecimals() external view returns (uint8) {
        return currentPhase.aggregatorY.decimals();
    }

    /**
     * @notice returns the current phase's aggregatorX' description.
     */
    function aggregatorXDescription() external view returns (string memory) {
        return currentPhase.aggregatorX.description();
    }

    /**
     * @notice returns the current phase's aggregatorY' description.
     */
    function aggregatorYDescription() external view returns (string memory) {
        return currentPhase.aggregatorY.description();
    }

    /**
     * @notice returns the current phase's ID.
     */
    function phaseId() external view returns (uint16) {
        return currentPhase.id;
    }

    /**
     * @notice Allows the owner to propose a new address for the aggregator
     * @param _aggregatorX The new address for the aggregatorX contract
     * @param _aggregatorY The new address for the aggregatorY contract

     */
    function proposeAggregators(
        address _aggregatorX,
        address _aggregatorY
    ) external onlyOwner {
        proposedAggregatorX = AggregatorV2V3Interface(_aggregatorX);
        proposedAggregatorY = AggregatorV2V3Interface(_aggregatorY);
    }

    /**
     * @notice Allows the owner to confirm and change the address
     * to the proposed aggregator
     * @dev Reverts if the given address doesn't match what was previously
     * proposed
     * @param _aggregatorX The new address for the aggregator contract
     * @param _aggregatorY The new address for the aggregator contract
     */
    function confirmAggregators(
        address _aggregatorX,
        address _aggregatorY
    ) external onlyOwner {
        require(
            _aggregatorX == address(proposedAggregatorX),
            "Invalid proposed aggregatorX"
        );
        require(
            _aggregatorY == address(proposedAggregatorY),
            "Invalid proposed aggregatorY"
        );
        delete proposedAggregatorX;
        delete proposedAggregatorY;
        setAggregators(_aggregatorX, _aggregatorY);
    }

    function addPhase(
        uint16 _phase,
        uint64 _originalIdX,
        uint64 _originalIdY
    ) internal pure returns (uint80) {
        return
            uint80(
                (uint256(_phase) << PHASE_OFFSET) |
                    (uint256(_originalIdX) << PHASE_OFFSET_AGGREGATORX) |
                    _originalIdY
            );
    }

    function parseIds(
        uint256 _roundId
    ) internal pure returns (uint16, uint32, uint32) {
        uint16 id = uint16(_roundId >> PHASE_OFFSET);
        uint32 aggregatorRoundIdX = uint32(
            _roundId >> PHASE_OFFSET_AGGREGATORX
        );
        uint32 aggregatorRoundIdY = uint32(_roundId);
        return (id, aggregatorRoundIdX, aggregatorRoundIdY);
    }

    function addPhaseIds(
        uint80 roundIdX,
        uint80 roundIdY,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRoundX,
        uint80 answeredInRoundY,
        uint16 id
    ) internal pure returns (uint80, int256, uint256, uint256, uint80) {
        return (
            addPhase(id, uint32(roundIdX), uint32(roundIdY)),
            answer,
            startedAt,
            updatedAt,
            addPhase(
                id,
                uint32(answeredInRoundX),
                uint32(answeredInRoundY)
            )
        );
    }

    /**
     * @notice Allows the owner to update the aggregators' contract address.
     * @param _aggregatorX The new address for the aggregator contract
     * @param _aggregatorY The new address for the aggregator contract
     */
    function setAggregators(
        address _aggregatorX,
        address _aggregatorY
    ) internal {
        uint16 id = currentPhase.id + 1;
        currentPhase = Phase(
            id,
            AggregatorV2V3Interface(_aggregatorX),
            AggregatorV2V3Interface(_aggregatorY)
        );
        phaseAggregators[id] = currentPhase;
    }

    function determineTimestamp(
        uint256 startedAtX,
        uint256 startedAtY,
        uint256 updatedAtX,
        uint256 updatedAtY
    ) internal pure returns (uint256 startedAt, uint256 updatedAt) {
        if (
            startedAtX == 0 ||
            startedAtY == 0 ||
            updatedAtX == 0 ||
            updatedAtY == 0
        ) {
            startedAt = 0;
            updatedAt = 0;
        } else {
            startedAt = startedAtX > startedAtY ? startedAtY : startedAtX;
            updatedAt = updatedAtX > updatedAtY ? updatedAtX : updatedAtY;
        }
    }

    function version() external view override returns (uint256) {
        return
            uint256(
                (currentPhase.aggregatorX.version() << 16) |
                    currentPhase.aggregatorY.version()
            );
    }

    /*
     * Modifiers
     */

    modifier hasProposal() {
        require(
            address(proposedAggregatorX) != address(0) &&
                address(proposedAggregatorY) != address(0),
            "No proposed aggregator present"
        );
        _;
    }
}

/**
 * @title A trusted proxy for updating where current answers are read from
 * @notice This contract provides a consistent address for the
 * CurrentAnwerInterface but delegates where it reads from to the owner, who is
 * trusted to update it.
 */

interface AccessControllerInterface {
    function hasAccess(
        address user,
        bytes calldata data
    ) external view returns (bool);
}

contract EACAggregatorCombineProxy is AggregatorCombineProxy {
    AccessControllerInterface public accessController;

    constructor(
        address _aggregatorX,
        address _aggregatorY,
        uint8 decimals,
        string memory description,
        address _accessController
    )
        AggregatorCombineProxy(
            _aggregatorX,
            _aggregatorY,
            decimals,
            description
        )
    {
        setController(_accessController);
    }

    /**
     * @notice Reads the current answer from aggregator delegated to.
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestAnswer() public view override checkAccess returns (int256) {
        return super.latestAnswer();
    }

    /**
     * @notice get the latest completed round where the answer was updated. This
     * ID includes the proxy's phase, to make sure round IDs increase even when
     * switching to a newly deployed aggregator.
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestTimestamp()
        public
        view
        override
        checkAccess
        returns (uint256)
    {
        return super.latestTimestamp();
    }

    /**
     * @notice get past rounds answers
     * @param _roundId the answer number to retrieve the answer for
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getAnswer(
        uint256 _roundId
    ) public view override checkAccess returns (int256) {
        return super.getAnswer(_roundId);
    }

    /**
     * @notice get block timestamp when an answer was last updated
     * @param _roundId the answer number to retrieve the updated timestamp for
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use getRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended getRoundData
     * instead which includes better verification information.
     */
    function getTimestamp(
        uint256 _roundId
    ) public view override checkAccess returns (uint256) {
        return super.getTimestamp(_roundId);
    }

    /**
     * @notice get the latest completed round where the answer was updated
     * @dev overridden function to add the checkAccess() modifier
     *
     * @dev #[deprecated] Use latestRoundData instead. This does not error if no
     * answer has been reached, it will simply return 0. Either wait to point to
     * an already answered Aggregator or use the recommended latestRoundData
     * instead which includes better verification information.
     */
    function latestRound() public view override checkAccess returns (uint256) {
        return super.latestRound();
    }

    /**
     * @notice get data about a round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with a phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function getRoundData(
        uint80 _roundId
    )
        public
        view
        override
        checkAccess
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.getRoundData(_roundId);
    }

    /**
     * @notice get data about the latest round. Consumers are encouraged to check
     * that they're receiving fresh data by inspecting the updatedAt and
     * answeredInRound return values.
     * Note that different underlying implementations of AggregatorV3Interface
     * have slightly different semantics for some of the return values. Consumers
     * should determine what implementations they expect to receive
     * data from and validate that they can properly handle return data from all
     * of them.
     * @return roundId is the round ID from the aggregator for which the data was
     * retrieved combined with a phase to ensure that round IDs get larger as
     * time moves forward.
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @dev Note that answer and updatedAt may change between queries.
     */
    function latestRoundData()
        public
        view
        override
        checkAccess
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.latestRoundData();
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @param _roundId the round ID to retrieve the round data for
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedGetRoundData(
        uint80 _roundId
    )
        public
        view
        override
        checkAccess
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.proposedGetRoundData(_roundId);
    }

    /**
     * @notice Used if an aggregator contract has been proposed.
     * @return roundId is the round ID for which data was retrieved
     * @return answer is the answer for the given round
     * @return startedAt is the timestamp when the round was started.
     * (Only some AggregatorV3Interface implementations return meaningful values)
     * @return updatedAt is the timestamp when the round last was updated (i.e.
     * answer was last computed)
     * @return answeredInRound is the round ID of the round in which the answer
     * was computed.
     */
    function proposedLatestRoundData()
        public
        view
        override
        checkAccess
        hasProposal
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return super.proposedLatestRoundData();
    }

    /**
     * @notice Allows the owner to update the accessController contract address.
     * @param _accessController The new address for the accessController contract
     */
    function setController(address _accessController) public onlyOwner {
        accessController = AccessControllerInterface(_accessController);
    }

    /**
     * @dev reverts if the caller does not have access by the accessController
     * contract or is the contract itself.
     */
    modifier checkAccess() {
        AccessControllerInterface ac = accessController;
        require(
            address(ac) == address(0) || ac.hasAccess(msg.sender, msg.data),
            "No access"
        );
        _;
    }
}
