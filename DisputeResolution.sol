// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Contract {
    event InitialEvidence(uint indexed _txID, string _evidence);
    event Dispute(address indexed _arbiterID, uint indexed _txID);
    event Evidence(address indexed _arbiterID, address indexed _user, uint indexed _txID, string _evidence);
    event PartialRefundSet(uint indexed _txID, address indexed _providerID, uint _percentage);

    enum Status {
        Binding,
        Execution,
        Dispute,
        Concluded
    }

    error TooEarlyForRefund();

    struct Transaction {
        address payable consumerID;
        address payable providerID;
        address payable arbiterID;
        uint decision;  // 0-consumer wins, 1-provider wins
        Status status;
        uint servicePrice;
        uint consumerFeeDeposit;
        uint providerFeeDeposit;
        bool arbiterConfirmation;

        uint contractTime;
        uint procedureTime;
        uint startOfContract;
    }

    Transaction[] public transactions;

    function newContract(
        address payable _providerID,
        address payable _arbiterID,
        uint _contractTime,
        string memory _initialEvidence
    ) public payable returns (uint txID) {
        emit InitialEvidence(transactions.length, _initialEvidence);

        transactions.push(
            Transaction({
                consumerID: payable(msg.sender),
                providerID: _providerID,
                arbiterID: _arbiterID,
                decision: 0,
                status: Status.Binding,
                servicePrice: msg.value,
                consumerFeeDeposit: 0,
                providerFeeDeposit: 0,
                arbiterConfirmation: false,

                contractTime: _contractTime,
                procedureTime: 5 minutes,
                startOfContract: block.timestamp
            })
        );
        txID = transactions.length;
        return txID;
    }

    function depositArbiterFeeProvider(uint _txID) public payable {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Address is not the provider of this transaction");
        require(transaction.status == Status.Binding, "Invalid contract status");
        require(transaction.providerFeeDeposit == 0, "Deposit has already been made");
        require(msg.value == 0.05 ether, "Exact deposit amount is required");
        transaction.providerFeeDeposit = msg.value;

        if (transaction.providerFeeDeposit == 0.05 ether && transaction.arbiterConfirmation == true) {
            transaction.status = Status.Execution;
        }
    }

    function arbiterConfirmation(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.arbiterID, "Address is not the arbiter of this transaction");
        require(transaction.status == Status.Binding, "Invalid contract status");
        require(transaction.arbiterConfirmation == false, "Arbiter's participation has already been confirmed");
        transaction.arbiterConfirmation = true;

        if (transaction.providerFeeDeposit == 0.05 ether && transaction.arbiterConfirmation == true) {
            transaction.status = Status.Execution;
        }
    }

    function providerError(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Only the provider can acknowledge a service mistake");
        require(transaction.status == Status.Execution, "Invalid contract status");

        transaction.providerID.send(transaction.providerFeeDeposit);
        if (transaction.consumerFeeDeposit == 0) {
            transaction.consumerID.send(transaction.servicePrice + transaction.consumerFeeDeposit);
        } else {
            transaction.consumerID.send(transaction.servicePrice);
        }

        transaction.status = Status.Concluded;
    }

    function raiseDispute

(uint _txID, string memory _evidence) public payable {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.consumerID, "Only the consumer can initiate a dispute");
        require(block.timestamp - transaction.startOfContract > transaction.contractTime, "Too early to initiate a dispute");
        require(block.timestamp - transaction.startOfContract < transaction.contractTime + transaction.procedureTime, "Too late to initiate a dispute");
        require(transaction.status != Status.Dispute, "Dispute has already been initiated");
        require(msg.value == 0.05 ether, "Exact payment of arbitration fee is required");

        transaction.consumerFeeDeposit = msg.value;
        transaction.status = Status.Dispute;
        emit Dispute(transaction.arbiterID, _txID);
        emit Evidence(transaction.arbiterID, transaction.consumerID, _txID, _evidence);
    }

    function uploadEvidence(uint _txID, string memory _evidence) public {
        Transaction storage transaction = transactions[_txID];

        require(transaction.status == Status.Dispute, "Invalid contract status, must be in Dispute");
        require(block.timestamp - transaction.startOfContract <= transaction.contractTime + transaction.procedureTime * 2, "Too late to submit evidence");

        if (msg.sender == transaction.providerID) {
            emit Evidence(transaction.arbiterID, msg.sender, _txID, _evidence);
        } else if (msg.sender == transaction.consumerID) {
            emit Evidence(transaction.arbiterID, msg.sender, _txID, _evidence);
        }
    }

    function Decision(uint _txID, uint _decision) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.arbiterID, "Only the arbiter can make a decision");
        require(transaction.status == Status.Dispute);
        require(block.timestamp - transaction.startOfContract < transaction.contractTime + transaction.procedureTime * 3, "Too late to make a decision");
        require(block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime * 2, "Too early to make a decision, proofs can still be submitted");
        require(_decision == 0 || _decision == 1, "Decision must be 0 (consumer) or 1 (provider)");
        transaction.decision = _decision;
        transaction.status = Status.Concluded;
    }

    function releaseFunds(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Not the consumer of this transaction");
        require(block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime, "Too early to release funds");

        if (transaction.status != Status.Dispute) {
            transaction.providerID.send(transaction.servicePrice + transaction.providerFeeDeposit);
            transaction.status = Status.Concluded;

        } else if (transaction.status == Status.Dispute) {
            require(block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime * 3,
                "The arbiter's decision period has not yet expired");
            require(transaction.decision == 1, "The provider did not win");
            transaction.providerID.send(transaction.servicePrice + transaction.providerFeeDeposit);
        }
    }

    function refundFunds(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.consumerID, "Only the consumer can request a refund");

        if (block.timestamp - transaction.startOfContract <= transaction.procedureTime) {
            revert TooEarlyForRefund();
        }

        if (block.timestamp - transaction.startOfContract > transaction.procedureTime ) {
            require(transaction.providerFeeDeposit == 0.05

 ether || transaction.consumerFeeDeposit == 0.05 ether,
                "Binding was successful, funds cannot be refunded");
            transaction.consumerID.send(transaction.servicePrice);
            transaction.status = Status.Concluded;

        } else if (block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime * 3){
            require(transaction.status != Status.Dispute, "Contract status is not in dispute");
            require(transaction.decision == 0, "The consumer did not win the dispute");
            transaction.consumerID.send(transaction.servicePrice + transaction.consumerFeeDeposit);
        }
    }

    function setPartialRefund(uint _txID) public payable {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Only the provider can offer a partial refund");
        require(transaction.status == Status.Execution, "Invalid contract status");
        require(msg.value == 0.05 ether || msg.value == 0.05 ether * 2 || msg.value == 0.05 ether * 3, "Exact deposit amount is required");

        transaction.consumerFeeDeposit += msg.value;

        if (msg.value == 0.05 ether) {
            emit PartialRefundSet(_txID, msg.sender, 25);
        } else if (msg.value == 0.05 ether * 2) {
            emit PartialRefundSet(_txID, msg.sender, 50);
        } else if (msg.value == 0.05 ether * 3) {
            emit PartialRefundSet(_txID, msg.sender, 75);
        }
    }

    function payPartially(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.consumerID, "Only the consumer can make a partial payment");
        require(transaction.status == Status.Execution, "Invalid contract status");

        if (transaction.consumerFeeDeposit == 0.05 ether * 2) {
            transaction.consumerID.send(transaction.servicePrice / 4);
            transaction.providerID.send(transaction.servicePrice * 3 / 4 + transaction.providerFeeDeposit);
            transaction.status = Status.Concluded;

        } else if (transaction.consumerFeeDeposit == 0.05 ether * 3) {
            transaction.consumerID.send(transaction.servicePrice / 2);
            transaction.providerID.send(transaction.servicePrice / 2 + transaction.providerFeeDeposit);
            transaction.status = Status.Concluded;

        } else if (transaction.consumerFeeDeposit == 0.05 ether * 4) {
            transaction.consumerID.send(transaction.servicePrice * 3 / 4);
            transaction.providerID.send(transaction.servicePrice / 4 + transaction.providerFeeDeposit);
            transaction.status = Status.Concluded;
        }
    }
}