# Contributing

Bug reports and pull requests are welcome.

When changing the script:

1. Keep Windows PowerShell 5.1 compatibility unless the documented minimum version changes.
2. Do not introduce user-specific paths, fixed interface indexes, or fixed gateway addresses.
3. Keep modifying operations reversible and scoped to the detected Radmin adapter.
4. Parse-check the script and test `-Action Status` on a Windows system before submitting.
5. Never commit `.radmin-vpn-fix-state.json`; it contains machine-local network details.

Please describe the Windows and PowerShell versions used for testing in the pull request.
