# Known issues and next steps

- add events for all state changing functions
- stale price check timeout should be changed depending on what chain protocol is deployed to
- need to check sequencer status when checking price staleness on Arbitrum
- add additional price oracles to act as fallbacks in case one is down 
- need to verify price feed decimals for collateral/usd price feeds instead of always assuming 1e8
- possibly add minimum balance check so small accounts are still worth liquidating or else small collateral balances could become unliquidatable
- need to refactor internal functions and break them up to give more control over when external calls happen so functions like `liquidate()` still follow CEI
- need to add a mechanism to allow liquidations even when there is not enough circulating DSC (otherwise liquidators may need to deposit/mint first and then can't immediately withdraw)
  - option: add a flash mint / flash loan liquidation path
    - design idea: mint DSC to the liquidator for the duration of the liquidation tx; burn it by the end of the tx
    - route the seized collateral (equal to the repaid debt) to a protocol receiver address stored in the constructor; route only the liquidation bonus collateral to the liquidator who initiated the flash mint
    - keep the flash amount bounded by the value of collateral being redeemed so the protocol is never undercollateralized mid-tx
  - option: allow liquidations using another stablecoin besides DSC (and swap/burn to reduce bad debt)
- maybe change use of transferFrom and burn in `DSCEngine::_burnDsc` to strictly burnFrom? could streamline the process and limit the amount of external calls. Would also have to change DecentralizedStableCoin contracts burn and burnFrom functions to support that
- need to implement solution to front running attacks on liquidators
