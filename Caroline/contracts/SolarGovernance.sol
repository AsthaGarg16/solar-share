// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SolarShare.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// 定义接口，用于指挥 Project 合约
// Define interface to interact with the Project contract
interface ISolarProject {
    function withdrawMaintenance(address _receiver, uint256 _amount) external;
}

/**
 * @title SolarGovernance
 * @dev 太阳能项目治理合约：基于 SLS 股份权重投票，决策维修基金的去向。
 * @dev Governance contract for solar projects: uses SLS token-weighted voting to decide maintenance fund allocation.
 */
contract SolarGovernance is Ownable {
    SolarShare public shareToken;
    address public projectContract; // 关联的项目主合约 Associated main project contract

    struct Proposal {
        string description;    // 报修内容描述 Maintenance description
        uint256 amount;        // 申请金额 Requested amount
        address receiver;      // 维修方收款地址 Address receiving maintenance funds
        uint256 votesFor;      // 累计赞成票数（SLS 权重） Total votes in favor (weighted by SLS)
        uint256 deadline;      // 投票截止时间 Voting deadline
        bool executed;         // 执行状态 Execution status
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, string desc, uint256 amount, address receiver);
    event Voted(uint256 indexed proposalId, address voter, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId, address receiver, uint256 amount);

    /**
     * @dev 构造函数：initialOwner 通常为 Factory，随后移交给项目方
     * @dev Constructor: initialOwner is usually the Factory, later transferred to the project owner
     */
    constructor(address _shareAddress, address _initialOwner) Ownable(_initialOwner) {
        shareToken = SolarShare(_shareAddress);
    }

    /**
     * @notice 绑定项目合约
     * @notice Bind the project contract
     * @dev 仅限 Owner（Factory）在初始化阶段设置一次
     * @dev Can only be set once by the Owner (Factory) during initialization
     */
    function setProjectContract(address _project) external onlyOwner {
        require(projectContract == address(0), "Project already set");
        projectContract = _project;
    }

    /**
     * @notice 发起维修提案
     * @notice Create a maintenance proposal
     * @dev 去掉了 onlyOwner 限制，允许任何人（或业主）报修，最终由投票决定是否给钱
     * @dev Removed onlyOwner restriction: anyone (or host) can propose, final decision is made by voting
     */
    function createProposal(
        string memory _desc, 
        uint256 _amount, 
        address _receiver
    ) external returns (uint256) {
        require(_amount > 0, "Amount must > 0");
        require(_receiver != address(0), "Invalid receiver");

        uint256 proposalId = proposals.length;
        proposals.push(Proposal({
            description: _desc,
            amount: _amount,
            receiver: _receiver,
            votesFor: 0,
            deadline: block.timestamp + 3 days, // 默认 3 天投票期 Default voting period: 3 days
            executed: false
        }));

        emit ProposalCreated(proposalId, _desc, _amount, _receiver);
        return proposalId;
    }

    /**
     * @notice 投票
     * @notice Vote on a proposal
     * @param _proposalId 提案 ID
     * @param _proposalId Proposal ID
     */
    function vote(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.deadline, "Voting expired");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");

        uint256 weight = shareToken.balanceOf(msg.sender);
        require(weight > 0, "No voting power (must hold SLS)");

        p.votesFor += weight;
        hasVoted[_proposalId][msg.sender] = true;

        emit Voted(_proposalId, msg.sender, weight);
    }

    /**
     * @notice 执行提案
     * @notice Execute proposal
     * @dev 跨合约调用 Project 合约的 withdrawMaintenance
     * @dev Cross-contract call to Project's withdrawMaintenance function
     */
    function executeProposal(uint256 _proposalId) external {
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        
        uint256 totalSupply = shareToken.totalSupply();
        require(totalSupply > 0, "No shares issued");

        // 核心阈值：赞成票 > 50% 总供给
        // Core threshold: votes in favor > 50% of total supply
        // 注意：如果是紧急维修，可以根据需求调整比例
        // Note: threshold can be adjusted for emergency cases
        require(p.votesFor > totalSupply / 2, "Insufficient support (>50% required)");

        p.executed = true;
        
        // 【跨合约指令】：指挥 Project 合约放款
        // Cross-contract instruction: trigger fund release from Project contract
        ISolarProject(projectContract).withdrawMaintenance(p.receiver, p.amount);

        emit ProposalExecuted(_proposalId, p.receiver, p.amount);
    }

    // 查询提案总数
    // Get total number of proposals
    function getProposalsCount() external view returns (uint256) {
        return proposals.length;
    }
}