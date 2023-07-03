// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// This contract facilitates transactions between consumers and providers
contract Contract {
    // Event declarations
    event InitialEvidence(uint indexed _txID, string _evidence); // initial evidence submitted at the start of a transaction
    event Dispute(address indexed _arbiterID, uint indexed _txID); // a dispute has been raised
    event Evidence(address indexed _arbiterID, address indexed _user, uint indexed _txID, string _evidence); // additional evidence submitted
    event PartialRefundSet(uint indexed _txID, address indexed _providerID, uint _percentage); // percentage of refund set by provider

    // Enum for the various states a transaction can be in
    enum Status {
        Binding, // when the contract is being formed
        Execution, // when the contract is in progress
        Dispute, // when there is a dispute
        Concluded // when the contract has concluded
    }

    // Custom error for trying to refund too early
    error TooEarlyForRefund();

    // Struct for storing the details of a transaction
    struct Transaction {
        address payable consumerID; // address of consumer
        address payable providerID; // address of provider
        address payable arbiterID; // address of arbiter
        uint decision;  // 0-consumer wins, 1-provider wins
        Status status; // current status of the transaction
        uint servicePrice; // cost of service
        uint consumerFeeDeposit; // fees deposited by consumer
        uint providerFeeDeposit; // fees deposited by provider
        bool arbiterConfirmation; // whether arbiter has confirmed to arbitrate

        uint contractTime; // expected duration of contract
        uint procedureTime; // duration of arbitration procedure
        uint startOfContract; // timestamp of contract start
    }

    // Array to store all transactions (agreements/contracts)
    Transaction[] public transactions;

    // Function to create a new contract
    function newContract(
        address payable _providerID,
        address payable _arbiterID,
        uint _contractTime,
        string memory _initialEvidence
    ) public payable returns (uint txID) {
        // Emit event with initial evidence
        emit InitialEvidence(transactions.length, _initialEvidence);

        // Add new transaction/agreement to transactions array
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

        // Return ID of new transaction/agreement
        txID = transactions.length;
        return txID;
    }

    // Function for the provider to deposit their fee
    function depositArbiterFeeProvider(uint _txID) public payable {
        // Access the transaction/agreement
        Transaction storage transaction = transactions[_txID];

        // Check for various conditions
        require(msg.sender == transaction.providerID, "Address is not the provider of this transaction");
        require(transaction.status == Status.Binding, "Invalid contract status");
        require(transaction.providerFeeDeposit == 0, "Deposit has already been made");
        require(msg.value == 0.05 ether, "Exact deposit amount is required");

        // Update deposit
        transaction.providerFeeDeposit = msg.value;

        // If provider has deposited the fee and arbiter has confirmed, change status to Execution
        if (transaction.providerFeeDeposit == 0.05 ether && transaction.arbiterConfirmation == true) {
            transaction.status = Status.Execution;
        }
    }

    // Function for arbiter to confirm their participation
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

    // Function for provider to acknowledge error and refund customer
    function providerError(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Only the provider can acknowledge a service mistake");
        require(transaction.status == Status.Execution, "Invalid contract status");

        transaction.providerID.transfer(transaction.providerFeeDeposit);
        if (transaction.consumerFeeDeposit == 0) {
            transaction.consumerID.transfer(transaction.servicePrice + transaction.consumerFeeDeposit);
        } else {
            transaction.consumerID.transfer(transaction.servicePrice);
        }

        transaction.status = Status.Concluded;
    }

    // Function for consumer to raise a dispute
    function raiseDispute(uint _txID, string memory _evidence) public payable {
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

    // Function for uploading evidence during a dispute
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

    // Function for arbiter to make a decision in a dispute
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

    // Function for provider to release funds
    function releaseFunds(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Not the consumer of this transaction");
        require(block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime, "Too early to release funds");

        // If contract is not in dispute, transfer funds to provider
        if (transaction.status != Status.Dispute) {
            transaction.providerID.transfer(transaction.servicePrice + transaction.providerFeeDeposit);
            transaction.status = Status.Concluded;

        } else if (transaction.status == Status.Dispute) {
            require(block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime * 3,
                "The arbiter's decision period has not yet expired");
            require(transaction.decision == 1, "The provider did not win");
            transaction.providerID.transfer(transaction.servicePrice + transaction.providerFeeDeposit);
        }
    }

    // Function for consumer to request a refund
    function refundFunds(uint _txID) public {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.consumerID, "Only the consumer can request a refund");

        // Refund logic here based on different conditions
        if (block.timestamp - transaction.startOfContract <= transaction.procedureTime) {
            revert TooEarlyForRefund();
        }

        if (block.timestamp - transaction.startOfContract > transaction.procedureTime ) {
            require(transaction.providerFeeDeposit == 0.05

 ether || transaction.consumerFeeDeposit == 0.05 ether,
                "Binding was successful, funds cannot be refunded");
            transaction.consumerID.transfer(transaction.servicePrice);
            transaction.status = Status.Concluded;

        } else if (block.timestamp - transaction.startOfContract > transaction.contractTime + transaction.procedureTime * 3){
            require(transaction.status != Status.Dispute, "Contract status is not in dispute");
            require(transaction.decision == 0, "The consumer did not win the dispute");
            transaction.consumerID.transfer(transaction.servicePrice + transaction.consumerFeeDeposit);
        }
    }

    // Function for provider to offer a partial refund
    function setPartialRefund(uint _txID) public payable {
        Transaction storage transaction = transactions[_txID];

        require(msg.sender == transaction.providerID, "Only the provider can offer a partial refund");
        require(transaction.status == Status.Execution, "Invalid contract status");
        require(msg.value == 0.05 ether || msg.value == 0.05 ether * 2 || msg.value == 0.05 ether * 3, "Exact deposit amount is required");

        transaction.consumerFeeDeposit += msg.value;

        // Emitting events based on different partial refund rates
        if (msg.value == 0.05 ether) {
            emit PartialRefundSet(_txID, msg.sender, 25);
        } else if (msg.value == 0.05 ether * 2) {
            emit PartialRefundSet(_txID, msg.sender, 50);
        } else if (msg.value == 0.05 ether * 3) {
            emit PartialRefundSet(_txID, msg.sender, 75);
        }
    }

    // Function to view the current status of a transaction
    function getStatus(uint _txID) public view returns (Status) {
        Transaction memory transaction = transactions[_txID];
        return transaction.status;
    }
}
