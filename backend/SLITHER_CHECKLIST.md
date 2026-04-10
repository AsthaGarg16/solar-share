INFO:Detectors:
Detector: unused-return
MaintenanceDAO.requestWeatherVerification(uint256,string) (src/core/MaintenanceDAO.sol#240-244) ignores return value by WEATHER_ORACLE.requestWeatherCheck(proposal.projectId,zipCode) (src/core/MaintenanceDAO.sol#243)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#unused-return
INFO:Detectors:
Detector: missing-zero-check
RevenueDistributor.setLoanManager(address)._loanManager (src/core/RevenueDistributor.sol#72) lacks a zero-check on :
		- loanManager = _loanManager (src/core/RevenueDistributor.sol#73)
RevenueDistributor.setGridOracle(address)._oracle (src/core/RevenueDistributor.sol#76) lacks a zero-check on :
		- gridOracle = _oracle (src/core/RevenueDistributor.sol#77)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-zero-address-validation
INFO:Detectors:
Detector: reentrancy-benign
Reentrancy in RevenueDistributor.depositGridRevenue(uint256,uint256) (src/core/RevenueDistributor.sol#84-93):
	External calls:
	- USDC.safeTransferFrom(msg.sender,address(this),amount) (src/core/RevenueDistributor.sol#87)
	State variables written after the call(s):
	- projectRevenue[projectId].totalRevenue += amount (src/core/RevenueDistributor.sol#88)
	- _executeWaterfallInternal(projectId) (src/core/RevenueDistributor.sol#92)
		- pool.dividendPool += dividendAmount (src/core/RevenueDistributor.sol#124)
		- pool.maintenanceReserve += maintenanceAmount (src/core/RevenueDistributor.sol#125)
		- pool.insurancePool += insuranceAmount (src/core/RevenueDistributor.sol#126)
		- pool.dividendPerShare += (total * DIVIDEND_PERCENTAGE * PRECISION) / (100 * totalShares) (src/core/RevenueDistributor.sol#131)
		- pool.totalRevenue = 0 (src/core/RevenueDistributor.sol#134)
Reentrancy in RevenueDistributor.depositHostPayment(uint256,uint256) (src/core/RevenueDistributor.sol#95-105):
	External calls:
	- USDC.safeTransferFrom(msg.sender,address(this),amount) (src/core/RevenueDistributor.sol#98)
	State variables written after the call(s):
	- projectRevenue[projectId].totalRevenue += amount (src/core/RevenueDistributor.sol#99)
	- projectRevenue[projectId].currentMonth += 1 (src/core/RevenueDistributor.sol#100)
	- _executeWaterfallInternal(projectId) (src/core/RevenueDistributor.sol#104)
		- pool.dividendPool += dividendAmount (src/core/RevenueDistributor.sol#124)
		- pool.maintenanceReserve += maintenanceAmount (src/core/RevenueDistributor.sol#125)
		- pool.insurancePool += insuranceAmount (src/core/RevenueDistributor.sol#126)
		- pool.dividendPerShare += (total * DIVIDEND_PERCENTAGE * PRECISION) / (100 * totalShares) (src/core/RevenueDistributor.sol#131)
		- pool.totalRevenue = 0 (src/core/RevenueDistributor.sol#134)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-3
INFO:Detectors:
Detector: reentrancy-events
Reentrancy in MaintenanceDAO._finalizeExecution(uint256,bool) (src/core/MaintenanceDAO.sol#253-263):
	External calls:
	- REVENUE_DISTRIBUTOR.withdrawMaintenance(proposal.projectId,proposal.amount,proposal.vendor) (src/core/MaintenanceDAO.sol#259)
	Event emitted after the call(s):
	- FundsTransferred(proposalId,proposal.vendor,proposal.amount) (src/core/MaintenanceDAO.sol#261)
	- ProposalExecuted(proposalId,passed,proposal.yesVotes,proposal.noVotes) (src/core/MaintenanceDAO.sol#262)
Reentrancy in LoanManager.declareDefault(uint256) (src/core/LoanManager.sol#201-229):
	External calls:
	- HOST_REPUTATION.slashScore(host,DEFAULT_PENALTY) (src/core/LoanManager.sol#220)
	- SOLAR_PROJECT.setProjectDefaulted(projectId) (src/core/LoanManager.sol#221)
	- iotOracle.triggerHardwareLock(projectId) (src/core/LoanManager.sol#225)
	Event emitted after the call(s):
	- DefaultDeclared(projectId,loan.currentMonth + 1,host) (src/core/LoanManager.sol#228)
Reentrancy in RevenueDistributor.depositGridRevenue(uint256,uint256) (src/core/RevenueDistributor.sol#84-93):
	External calls:
	- USDC.safeTransferFrom(msg.sender,address(this),amount) (src/core/RevenueDistributor.sol#87)
	Event emitted after the call(s):
	- GridRevenueDeposited(projectId,amount,block.timestamp) (src/core/RevenueDistributor.sol#90)
	- WaterfallExecuted(projectId,dividendAmount,maintenanceAmount,insuranceAmount) (src/core/RevenueDistributor.sol#136)
		- _executeWaterfallInternal(projectId) (src/core/RevenueDistributor.sol#92)
Reentrancy in RevenueDistributor.depositHostPayment(uint256,uint256) (src/core/RevenueDistributor.sol#95-105):
	External calls:
	- USDC.safeTransferFrom(msg.sender,address(this),amount) (src/core/RevenueDistributor.sol#98)
	Event emitted after the call(s):
	- HostPaymentDeposited(projectId,amount,projectRevenue[projectId].currentMonth) (src/core/RevenueDistributor.sol#102)
	- WaterfallExecuted(projectId,dividendAmount,maintenanceAmount,insuranceAmount) (src/core/RevenueDistributor.sol#136)
		- _executeWaterfallInternal(projectId) (src/core/RevenueDistributor.sol#104)
Reentrancy in LoanManager.initializeLoan(uint256,uint256,uint256) (src/core/LoanManager.sol#125-152):
	External calls:
	- HOST_REPUTATION.incrementProjectsCreated(host) (src/core/LoanManager.sol#149)
	Event emitted after the call(s):
	- LoanInitialized(projectId,monthlyPayment,termMonths) (src/core/LoanManager.sol#151)
Reentrancy in SolarProject.withdrawFunds(uint256) (src/core/SolarProject.sol#80-99):
	External calls:
	- loanManager.initializeLoan(projectId,monthlyPayment,project.termMonths) (src/core/SolarProject.sol#92)
	- USDC.safeTransfer(project.host,amount) (src/core/SolarProject.sol#95)
	Event emitted after the call(s):
	- FundsWithdrawn(projectId,project.host,amount) (src/core/SolarProject.sol#97)
	- ProjectStatusChanged(projectId,ProjectStatus.Active) (src/core/SolarProject.sol#98)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#reentrancy-vulnerabilities-4
INFO:Detectors:
Detector: timestamp
LoanManager.payMonthlyInstallment(uint256) (src/core/LoanManager.sol#155-192) uses timestamp for comparisons
	Dangerous comparisons:
	- completed = loan.totalPaid >= loan.totalOwed (src/core/LoanManager.sol#175)
LoanManager.checkDefaultStatus(uint256) (src/core/LoanManager.sol#194-199) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp > loan.nextPaymentDue (src/core/LoanManager.sol#198)
LoanManager.declareDefault(uint256) (src/core/LoanManager.sol#201-229) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp <= loan.nextPaymentDue (src/core/LoanManager.sol#206)
MaintenanceDAO.castVote(uint256,bool) (src/core/MaintenanceDAO.sol#159-181) uses timestamp for comparisons
	Dangerous comparisons:
	- block.timestamp > proposal.votingDeadline (src/core/MaintenanceDAO.sol#167)
MaintenanceDAO.executeProposal(uint256) (src/core/MaintenanceDAO.sol#184-220) uses timestamp for comparisons
	Dangerous comparisons:
	- isTimeExpired = (block.timestamp > proposal.votingDeadline) (src/core/MaintenanceDAO.sol#196)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#block-timestamp
INFO:Detectors:
Detector: solc-version
Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- ^0.8.20 (src/core/HostReputation.sol#2)
	- ^0.8.20 (src/core/LoanManager.sol#2)
	- ^0.8.20 (src/core/MaintenanceDAO.sol#2)
	- ^0.8.20 (src/core/RevenueDistributor.sol#2)
	- ^0.8.20 (src/core/SolarProject.sol#2)
	- ^0.8.20 (src/interfaces/IHostReputation.sol#2)
	- ^0.8.20 (src/interfaces/ILoanManager.sol#2)
	- ^0.8.20 (src/interfaces/IOracles.sol#2)
	- ^0.8.20 (src/interfaces/IRevenueDistributor.sol#2)
	- ^0.8.20 (src/interfaces/ISolarProject.sol#2)
	- ^0.8.20 (src/interfaces/IWeatherOracle.sol#2)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity
INFO:Detectors:
Detector: missing-inheritance
HostReputation (src/core/HostReputation.sol#12-170) should inherit from IHostReputation (src/interfaces/IHostReputation.sol#4-25)
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#missing-inheritance
INFO:Detectors:
Detector: naming-convention
Parameter LoanManager.setRevenueDistributor(address)._distributor (src/core/LoanManager.sol#111) is not in mixedCase
Parameter LoanManager.setIoTOracle(address)._iotOracle (src/core/LoanManager.sol#116) is not in mixedCase
Variable LoanManager.SOLAR_PROJECT (src/core/LoanManager.sol#68) is not in mixedCase
Variable LoanManager.HOST_REPUTATION (src/core/LoanManager.sol#70) is not in mixedCase
Variable LoanManager.USDC (src/core/LoanManager.sol#71) is not in mixedCase
Variable MaintenanceDAO.SOLAR_PROJECT (src/core/MaintenanceDAO.sol#85) is not in mixedCase
Variable MaintenanceDAO.REVENUE_DISTRIBUTOR (src/core/MaintenanceDAO.sol#86) is not in mixedCase
Variable MaintenanceDAO.USDC (src/core/MaintenanceDAO.sol#87) is not in mixedCase
Variable MaintenanceDAO.WEATHER_ORACLE (src/core/MaintenanceDAO.sol#88) is not in mixedCase
Parameter RevenueDistributor.setLoanManager(address)._loanManager (src/core/RevenueDistributor.sol#72) is not in mixedCase
Parameter RevenueDistributor.setGridOracle(address)._oracle (src/core/RevenueDistributor.sol#76) is not in mixedCase
Variable RevenueDistributor.SOLAR_PROJECT (src/core/RevenueDistributor.sol#53) is not in mixedCase
Variable RevenueDistributor.USDC (src/core/RevenueDistributor.sol#54) is not in mixedCase
Parameter SolarProject.setLoanManager(address)._loanManager (src/core/SolarProject.sol#107) is not in mixedCase
Variable SolarProject.USDC (src/core/SolarProject.sol#68) is not in mixedCase
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#conformance-to-solidity-naming-conventions
INFO:Detectors:
Detector: immutable-states
LoanManager.gridOracle (src/core/LoanManager.sol#75) should be immutable 
LoanManager.weatherOracle (src/core/LoanManager.sol#74) should be immutable 
Reference: https://github.com/crytic/slither/wiki/Detector-Documentation#state-variables-that-could-be-declared-immutable
INFO:Slither:src/core/ analyzed (33 contracts with 101 detectors), 35 result(s) found
**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [unused-return](#unused-return) (1 results) (Medium)
 - [missing-zero-check](#missing-zero-check) (2 results) (Low)
 - [reentrancy-benign](#reentrancy-benign) (2 results) (Low)
 - [reentrancy-events](#reentrancy-events) (6 results) (Low)
 - [timestamp](#timestamp) (5 results) (Low)
 - [solc-version](#solc-version) (1 results) (Informational)
 - [missing-inheritance](#missing-inheritance) (1 results) (Informational)
 - [naming-convention](#naming-convention) (15 results) (Informational)
 - [immutable-states](#immutable-states) (2 results) (Optimization)
## unused-return
Impact: Medium
Confidence: Medium
 - [ ] ID-0
[MaintenanceDAO.requestWeatherVerification(uint256,string)](src/core/MaintenanceDAO.sol#L240-L244) ignores return value by [WEATHER_ORACLE.requestWeatherCheck(proposal.projectId,zipCode)](src/core/MaintenanceDAO.sol#L243)

src/core/MaintenanceDAO.sol#L240-L244


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-1
[RevenueDistributor.setGridOracle(address)._oracle](src/core/RevenueDistributor.sol#L76) lacks a zero-check on :
		- [gridOracle = _oracle](src/core/RevenueDistributor.sol#L77)

src/core/RevenueDistributor.sol#L76


 - [ ] ID-2
[RevenueDistributor.setLoanManager(address)._loanManager](src/core/RevenueDistributor.sol#L72) lacks a zero-check on :
		- [loanManager = _loanManager](src/core/RevenueDistributor.sol#L73)

src/core/RevenueDistributor.sol#L72


## reentrancy-benign
Impact: Low
Confidence: Medium
 - [ ] ID-3
Reentrancy in [RevenueDistributor.depositGridRevenue(uint256,uint256)](src/core/RevenueDistributor.sol#L84-L93):
	External calls:
	- [USDC.safeTransferFrom(msg.sender,address(this),amount)](src/core/RevenueDistributor.sol#L87)
	State variables written after the call(s):
	- [projectRevenue[projectId].totalRevenue += amount](src/core/RevenueDistributor.sol#L88)
	- [_executeWaterfallInternal(projectId)](src/core/RevenueDistributor.sol#L92)
		- [pool.dividendPool += dividendAmount](src/core/RevenueDistributor.sol#L124)
		- [pool.maintenanceReserve += maintenanceAmount](src/core/RevenueDistributor.sol#L125)
		- [pool.insurancePool += insuranceAmount](src/core/RevenueDistributor.sol#L126)
		- [pool.dividendPerShare += (total * DIVIDEND_PERCENTAGE * PRECISION) / (100 * totalShares)](src/core/RevenueDistributor.sol#L131)
		- [pool.totalRevenue = 0](src/core/RevenueDistributor.sol#L134)

src/core/RevenueDistributor.sol#L84-L93


 - [ ] ID-4
Reentrancy in [RevenueDistributor.depositHostPayment(uint256,uint256)](src/core/RevenueDistributor.sol#L95-L105):
	External calls:
	- [USDC.safeTransferFrom(msg.sender,address(this),amount)](src/core/RevenueDistributor.sol#L98)
	State variables written after the call(s):
	- [projectRevenue[projectId].totalRevenue += amount](src/core/RevenueDistributor.sol#L99)
	- [projectRevenue[projectId].currentMonth += 1](src/core/RevenueDistributor.sol#L100)
	- [_executeWaterfallInternal(projectId)](src/core/RevenueDistributor.sol#L104)
		- [pool.dividendPool += dividendAmount](src/core/RevenueDistributor.sol#L124)
		- [pool.maintenanceReserve += maintenanceAmount](src/core/RevenueDistributor.sol#L125)
		- [pool.insurancePool += insuranceAmount](src/core/RevenueDistributor.sol#L126)
		- [pool.dividendPerShare += (total * DIVIDEND_PERCENTAGE * PRECISION) / (100 * totalShares)](src/core/RevenueDistributor.sol#L131)
		- [pool.totalRevenue = 0](src/core/RevenueDistributor.sol#L134)

src/core/RevenueDistributor.sol#L95-L105


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-5
Reentrancy in [RevenueDistributor.depositHostPayment(uint256,uint256)](src/core/RevenueDistributor.sol#L95-L105):
	External calls:
	- [USDC.safeTransferFrom(msg.sender,address(this),amount)](src/core/RevenueDistributor.sol#L98)
	Event emitted after the call(s):
	- [HostPaymentDeposited(projectId,amount,projectRevenue[projectId].currentMonth)](src/core/RevenueDistributor.sol#L102)
	- [WaterfallExecuted(projectId,dividendAmount,maintenanceAmount,insuranceAmount)](src/core/RevenueDistributor.sol#L136)
		- [_executeWaterfallInternal(projectId)](src/core/RevenueDistributor.sol#L104)

src/core/RevenueDistributor.sol#L95-L105


 - [ ] ID-6
Reentrancy in [LoanManager.declareDefault(uint256)](src/core/LoanManager.sol#L201-L229):
	External calls:
	- [HOST_REPUTATION.slashScore(host,DEFAULT_PENALTY)](src/core/LoanManager.sol#L220)
	- [SOLAR_PROJECT.setProjectDefaulted(projectId)](src/core/LoanManager.sol#L221)
	- [iotOracle.triggerHardwareLock(projectId)](src/core/LoanManager.sol#L225)
	Event emitted after the call(s):
	- [DefaultDeclared(projectId,loan.currentMonth + 1,host)](src/core/LoanManager.sol#L228)

src/core/LoanManager.sol#L201-L229


 - [ ] ID-7
Reentrancy in [SolarProject.withdrawFunds(uint256)](src/core/SolarProject.sol#L80-L99):
	External calls:
	- [loanManager.initializeLoan(projectId,monthlyPayment,project.termMonths)](src/core/SolarProject.sol#L92)
	- [USDC.safeTransfer(project.host,amount)](src/core/SolarProject.sol#L95)
	Event emitted after the call(s):
	- [FundsWithdrawn(projectId,project.host,amount)](src/core/SolarProject.sol#L97)
	- [ProjectStatusChanged(projectId,ProjectStatus.Active)](src/core/SolarProject.sol#L98)

src/core/SolarProject.sol#L80-L99


 - [ ] ID-8
Reentrancy in [MaintenanceDAO._finalizeExecution(uint256,bool)](src/core/MaintenanceDAO.sol#L253-L263):
	External calls:
	- [REVENUE_DISTRIBUTOR.withdrawMaintenance(proposal.projectId,proposal.amount,proposal.vendor)](src/core/MaintenanceDAO.sol#L259)
	Event emitted after the call(s):
	- [FundsTransferred(proposalId,proposal.vendor,proposal.amount)](src/core/MaintenanceDAO.sol#L261)
	- [ProposalExecuted(proposalId,passed,proposal.yesVotes,proposal.noVotes)](src/core/MaintenanceDAO.sol#L262)

src/core/MaintenanceDAO.sol#L253-L263


 - [ ] ID-9
Reentrancy in [RevenueDistributor.depositGridRevenue(uint256,uint256)](src/core/RevenueDistributor.sol#L84-L93):
	External calls:
	- [USDC.safeTransferFrom(msg.sender,address(this),amount)](src/core/RevenueDistributor.sol#L87)
	Event emitted after the call(s):
	- [GridRevenueDeposited(projectId,amount,block.timestamp)](src/core/RevenueDistributor.sol#L90)
	- [WaterfallExecuted(projectId,dividendAmount,maintenanceAmount,insuranceAmount)](src/core/RevenueDistributor.sol#L136)
		- [_executeWaterfallInternal(projectId)](src/core/RevenueDistributor.sol#L92)

src/core/RevenueDistributor.sol#L84-L93


 - [ ] ID-10
Reentrancy in [LoanManager.initializeLoan(uint256,uint256,uint256)](src/core/LoanManager.sol#L125-L152):
	External calls:
	- [HOST_REPUTATION.incrementProjectsCreated(host)](src/core/LoanManager.sol#L149)
	Event emitted after the call(s):
	- [LoanInitialized(projectId,monthlyPayment,termMonths)](src/core/LoanManager.sol#L151)

src/core/LoanManager.sol#L125-L152


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-11
[LoanManager.declareDefault(uint256)](src/core/LoanManager.sol#L201-L229) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp <= loan.nextPaymentDue](src/core/LoanManager.sol#L206)

src/core/LoanManager.sol#L201-L229


 - [ ] ID-12
[MaintenanceDAO.executeProposal(uint256)](src/core/MaintenanceDAO.sol#L184-L220) uses timestamp for comparisons
	Dangerous comparisons:
	- [isTimeExpired = (block.timestamp > proposal.votingDeadline)](src/core/MaintenanceDAO.sol#L196)

src/core/MaintenanceDAO.sol#L184-L220


 - [ ] ID-13
[LoanManager.checkDefaultStatus(uint256)](src/core/LoanManager.sol#L194-L199) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > loan.nextPaymentDue](src/core/LoanManager.sol#L198)

src/core/LoanManager.sol#L194-L199


 - [ ] ID-14
[LoanManager.payMonthlyInstallment(uint256)](src/core/LoanManager.sol#L155-L192) uses timestamp for comparisons
	Dangerous comparisons:
	- [completed = loan.totalPaid >= loan.totalOwed](src/core/LoanManager.sol#L175)

src/core/LoanManager.sol#L155-L192


 - [ ] ID-15
[MaintenanceDAO.castVote(uint256,bool)](src/core/MaintenanceDAO.sol#L159-L181) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > proposal.votingDeadline](src/core/MaintenanceDAO.sol#L167)

src/core/MaintenanceDAO.sol#L159-L181


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-16
Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [^0.8.20](src/core/HostReputation.sol#L2)
	- [^0.8.20](src/core/LoanManager.sol#L2)
	- [^0.8.20](src/core/MaintenanceDAO.sol#L2)
	- [^0.8.20](src/core/RevenueDistributor.sol#L2)
	- [^0.8.20](src/core/SolarProject.sol#L2)
	- [^0.8.20](src/interfaces/IHostReputation.sol#L2)
	- [^0.8.20](src/interfaces/ILoanManager.sol#L2)
	- [^0.8.20](src/interfaces/IOracles.sol#L2)
	- [^0.8.20](src/interfaces/IRevenueDistributor.sol#L2)
	- [^0.8.20](src/interfaces/ISolarProject.sol#L2)
	- [^0.8.20](src/interfaces/IWeatherOracle.sol#L2)

src/core/HostReputation.sol#L2


## missing-inheritance
Impact: Informational
Confidence: High
 - [ ] ID-17
[HostReputation](src/core/HostReputation.sol#L12-L170) should inherit from [IHostReputation](src/interfaces/IHostReputation.sol#L4-L25)

src/core/HostReputation.sol#L12-L170


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-18
Variable [LoanManager.SOLAR_PROJECT](src/core/LoanManager.sol#L68) is not in mixedCase

src/core/LoanManager.sol#L68


 - [ ] ID-19
Variable [MaintenanceDAO.WEATHER_ORACLE](src/core/MaintenanceDAO.sol#L88) is not in mixedCase

src/core/MaintenanceDAO.sol#L88


 - [ ] ID-20
Variable [MaintenanceDAO.USDC](src/core/MaintenanceDAO.sol#L87) is not in mixedCase

src/core/MaintenanceDAO.sol#L87


 - [ ] ID-21
Parameter [LoanManager.setRevenueDistributor(address)._distributor](src/core/LoanManager.sol#L111) is not in mixedCase

src/core/LoanManager.sol#L111


 - [ ] ID-22
Variable [RevenueDistributor.USDC](src/core/RevenueDistributor.sol#L54) is not in mixedCase

src/core/RevenueDistributor.sol#L54


 - [ ] ID-23
Variable [RevenueDistributor.SOLAR_PROJECT](src/core/RevenueDistributor.sol#L53) is not in mixedCase

src/core/RevenueDistributor.sol#L53


 - [ ] ID-24
Parameter [SolarProject.setLoanManager(address)._loanManager](src/core/SolarProject.sol#L107) is not in mixedCase

src/core/SolarProject.sol#L107


 - [ ] ID-25
Parameter [LoanManager.setIoTOracle(address)._iotOracle](src/core/LoanManager.sol#L116) is not in mixedCase

src/core/LoanManager.sol#L116


 - [ ] ID-26
Parameter [RevenueDistributor.setLoanManager(address)._loanManager](src/core/RevenueDistributor.sol#L72) is not in mixedCase

src/core/RevenueDistributor.sol#L72


 - [ ] ID-27
Variable [MaintenanceDAO.SOLAR_PROJECT](src/core/MaintenanceDAO.sol#L85) is not in mixedCase

src/core/MaintenanceDAO.sol#L85


 - [ ] ID-28
Variable [LoanManager.HOST_REPUTATION](src/core/LoanManager.sol#L70) is not in mixedCase

src/core/LoanManager.sol#L70


 - [ ] ID-29
Variable [MaintenanceDAO.REVENUE_DISTRIBUTOR](src/core/MaintenanceDAO.sol#L86) is not in mixedCase

src/core/MaintenanceDAO.sol#L86


 - [ ] ID-30
Variable [SolarProject.USDC](src/core/SolarProject.sol#L68) is not in mixedCase

src/core/SolarProject.sol#L68


 - [ ] ID-31
Parameter [RevenueDistributor.setGridOracle(address)._oracle](src/core/RevenueDistributor.sol#L76) is not in mixedCase

src/core/RevenueDistributor.sol#L76


 - [ ] ID-32
Variable [LoanManager.USDC](src/core/LoanManager.sol#L71) is not in mixedCase

src/core/LoanManager.sol#L71


## immutable-states
Impact: Optimization
Confidence: High
 - [ ] ID-33
[LoanManager.gridOracle](src/core/LoanManager.sol#L75) should be immutable 

src/core/LoanManager.sol#L75


 - [ ] ID-34
[LoanManager.weatherOracle](src/core/LoanManager.sol#L74) should be immutable 

src/core/LoanManager.sol#L74


