// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Bidding is AccessControl {
    bytes32 public constant PRODUCER_ROLE = keccak256("PRODUCER_ROLE");
    bytes32 public constant CARRIER_ROLE = keccak256("CARRIER_ROLE");

    struct Bid {
        uint256 contractId;
        address carrier;
        uint256 amount;
        uint256 timestamp;
    }

    struct TransportationContract {
        uint256 contractId;
        address producer;
        string details;
        uint256 startTime;
        uint256 endTime;
        bool awarded;
        address awardedCarrier;
        uint256 awardedAmount;
        uint256 bidsCount;
        mapping(uint256 => Bid) bids;
    }

    mapping(uint256 => TransportationContract) public contracts;
    uint256 public contractCounter;

    event TransportationContractCreated(uint256 contractId, address producer, string details, uint256 startTime, uint256 endTime);
    event BidPlaced(uint256 contractId, address carrier, uint256 amount);
    event ContractAwarded(uint256 contractId, address awardedCarrier, uint256 awardedAmount);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PRODUCER_ROLE, msg.sender);
        _grantRole(CARRIER_ROLE, msg.sender);
    }

     function createTransportContract(string memory details, uint256 endTime) public onlyRole(PRODUCER_ROLE) {
        require(endTime > block.timestamp, "End time must be in the future");

        contractCounter++;
        TransportationContract storage newContract = contracts[contractCounter]; // Get storage reference
        newContract.contractId = contractCounter;
        newContract.producer = msg.sender;
        newContract.details = details;
        newContract.startTime = block.timestamp;
        newContract.endTime = endTime;
        newContract.awarded = false;
        newContract.awardedCarrier = address(0);
        newContract.awardedAmount = 0;
        newContract.bidsCount = 0;

        emit TransportationContractCreated(contractCounter, msg.sender, details, block.timestamp, endTime);
    }

    function placeBid(uint256 contractId, uint256 amount) public onlyRole(CARRIER_ROLE) {
        TransportationContract storage transportContract = contracts[contractId];
        require(block.timestamp < transportContract.endTime, "Bidding period has ended");
        require(!transportContract.awarded, "Contract already awarded");
        uint256 bidIndex = transportContract.bidsCount;

         transportContract.bids[bidIndex] = Bid({
            contractId: contractId,
            carrier: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        });
         transportContract.bidsCount++;


        emit BidPlaced(contractId, msg.sender, amount);
    }

    function awardContract(uint256 contractId) public onlyRole(PRODUCER_ROLE) {
        TransportationContract storage transportContract = contracts[contractId];
        require(block.timestamp >= transportContract.endTime, "Bidding time is not over");
        require(!transportContract.awarded, "Contract already awarded");

        uint256 lowestBid = type(uint256).max;
        address lowestBidder = address(0);

        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            if (transportContract.bids[i].amount < lowestBid) {
                lowestBid = transportContract.bids[i].amount;
                lowestBidder = transportContract.bids[i].carrier;
            }
        }

        require(lowestBidder != address(0), "No valid bids");

        transportContract.awarded = true;
        transportContract.awardedCarrier = lowestBidder;
        transportContract.awardedAmount = lowestBid;

        emit ContractAwarded(contractId, lowestBidder, lowestBid);
    }


     function getBids(uint256 contractId) public view returns (Bid[] memory) {
        TransportationContract storage transportContract = contracts[contractId];
        Bid[] memory bidsArray = new Bid[](transportContract.bidsCount);
        for (uint256 i = 0; i < transportContract.bidsCount; i++) {
            bidsArray[i] = transportContract.bids[i];
        }
        return bidsArray;
    }


    function getBid(uint256 contractId, uint256 bidIndex) public view returns (Bid memory){
        TransportationContract storage transportContract = contracts[contractId];
        require(bidIndex < transportContract.bidsCount, "Invalid bid index");
        return transportContract.bids[bidIndex];
    }
}