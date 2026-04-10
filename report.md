# Test Report

## Command

```bash
cd packages/hardhat
forge test -vvv
```

## Output

```text
[⠒] Compiling...
No files changed, compilation skipped

Ran 2 tests for test/GracePeriod.t.sol:GracePeriodTest
[PASS] testFlashLoanLiquidatorBlockedThenAllowed() (gas: 391278)
[PASS] testGracePeriodResetsWhenRecovered() (gas: 247372)
Suite result: ok. 2 passed; 0 failed; 0 skipped; finished in 53.61ms (38.24ms CPU time)

Ran 1 test suite in 229.88ms (53.61ms CPU time): 2 tests passed, 0 failed, 0 skipped (2 total tests)
```
