# Dispute Resolution Contract

This contract was developed as a proof of concept for a contract creation and dispute resolution for the shared manufacturing concept. This contract can be used in a situation where there is a service agreement between a consumer and provider and an arbiter is required to oversee the transaction and dispute resolution if needed. The contract handles various scenarios such as a dispute, error in service, partial refunds, and payments. 

## Contract Details

The contract allows for creating transactions between a consumer and a provider, with an arbiter as a third party. It supports evidence submission, disputes, partial refunds, and further negotiation.

### Contract Phases:

1. **Binding**: The consumer initiates the contract after negotiations. They establish the contract by selecting the provider, the arbiter, the service price, the arbiter fee, the contract time, and the procedure time. The contract enters the "Execution" phase once both the provider and arbiter have confirmed their participation.

2. **Execution**: In this phase, the provider delivers the service to the consumer. If the provider acknowledges a mistake, they can return the funds to the consumer, concluding the transaction. The provider can also offer a partial refund in this phase, which, if accepted by the consumer, also concludes the transaction.

3. **Dispute**: If the consumer is not satisfied with the service, they can raise a dispute by submitting evidence. Both the consumer and the provider can submit additional evidence during a dispute. The arbiter then makes a decision, declaring the dispute resolved and concluding the transaction.

### Functions:

1. `newContract`: This function creates a new transaction between a consumer and a provider. The consumer attaches an initial piece of evidence / service documentation (an URL do a database e.g. IPFS ).

2. `depositArbiterFeeProvider`: This function allows the provider to deposit their fee for the arbiter. This changes the transaction status to `Execution` if the arbiter has confirmed their participation.

3. `arbiterConfirmation`: Allows the arbiter to confirm their participation in the transaction.

4. `providerError`: To be called if the provider acknowledges a mistake. This will return the funds to the consumer and conclude the transaction.

5. `raiseDispute`: If the consumer believes that the service was not provided as expected, they can raise a dispute and provide evidence.

6. `uploadEvidence`: During a dispute, both the consumer and the provider can upload additional evidence.

7. `Decision`: The arbiter can make a decision on a dispute, declaring a winner.

8. `releaseFunds`: To be used by the provider to claim the funds after successful service delivery.

9. `refundFunds`: If the service was not delivered as expected and the provider did not acknowledge a mistake, the consumer can request a refund.

10. `setPartialRefund`: The provider can offer a partial refund to the consumer.

11. `payPartially`: To be used by the consumer to accept a partial refund and make a partial payment.

## Additional Information

The contract includes a mechanism for additional negotiation, in case the parties can resolve their dispute by themselves. It offers options for 25%, 50%, 75%, and 100% refunds.

In case of a full refund, the provider acknowledges a mistake and returns the service fee to the consumer.

For partial refunds, the provider sets a refund rate and the consumer confirms it. The contract then redistributes the funds accordingly.

Once the contract is resolved (either through the provider's acknowledgement of a mistake, a decision by the arbiter, or acceptance of a partial refund by the consumer), the contract concludes and the remaining funds are returned.

The contract is designed with a focus on security, with checks to ensure that only the appropriate parties can call functions at the correct times and that funds are correctly deposited.

Please refer to the code comments for more details on the conditions and process flow of the contract.

