/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.5.4;


contract Crowdfunding {
    Project[] private projects;

    // событие срабатывает при запуске контракта
    event ProjectStarted(
        address contractAddress,
        address projectStarter,
        string projectTitle,
        string projectDesc,
        uint256 deadline,
        uint256 goalAmount
    );

    /** @dev Function для основания проекта
      * @param title название проекта
      * @param description короткое описание проекта
      * @param durationInDays период сбора пожертвований (дни)
      * @param amountToRaise требуемая сумма
      */
    function startProject(string calldata title, string calldata description, uint durationInDays, uint amountToRaise) external {
        uint raiseUntil = block.timestamp + durationInDays * 1 days;
        Project newProject = new Project(msg.sender, title, description, raiseUntil, amountToRaise);
        projects.push(newProject);
        emit ProjectStarted(
            address(newProject),
            msg.sender,
            title,
            description,
            raiseUntil,
            amountToRaise
        );
    }                                                                                                                                   

    /** @dev для возврата всех активных проектов
      */
    function returnAllProjects() external view returns(Project[] memory){
        return projects;
    }
}


contract Project {

    address payable public creator;
    uint public amountGoal; // сумма необходимая для проекта, иначе будет произведен возврат
    uint public completeAt;
    uint256 public currentBalance;
    uint public raiseBy;
    string public title;
    string public description;
    uint state = 0; // стадия контракта (инициализируется при активировании проекта)
    // 0 - требует финансирование, 1 - собранная недостаточная сумма, 2 - сумма собрана успешно
    mapping (address => uint) public contributions;

    // событие срабатывает когда на счет проекта поступает пожертвование
    event FundingReceived(address contributor, uint amount, uint currentTotal);
    // другое событие срабатывает когда на счет проекта поступает пожертвование
    event CreatorPaid(address recipient);


    constructor (address payable projectStarter, string memory projectTitle, string memory projectDesc, uint fundRaisingDeadline, uint goalAmount) public {
        creator = projectStarter;
        title = projectTitle;
        description = projectDesc;
        amountGoal = goalAmount;
        raiseBy = fundRaisingDeadline;
        currentBalance = 0;
    }

    /** @dev функция "пожертвование"
      */
    function contribute() external payable {
        require(state == 0);
        require(msg.sender != creator);
        contributions[msg.sender] += msg.value;
        currentBalance += msg.value;
        emit FundingReceived(msg.sender, msg.value, currentBalance);
        checkIfFundingCompleteOrExpired();
    }

    /** @dev функция для изменения стадии проекта
      */
    function checkIfFundingCompleteOrExpired() public {
        if (currentBalance >= amountGoal) {
            state = 2;
            payOut();
        } else if (now > raiseBy)  {
            state = 1;
        }
        completeAt = now;
    }

    /** @dev функция для возврата пожертвований
      */
    function payOut() internal returns (bool) {
        require(state == 2);
        uint256 totalRaised = currentBalance;
        currentBalance = 0;

        if (creator.send(totalRaised)) {
            emit CreatorPaid(creator);
            return true;
        } else {
            currentBalance = totalRaised;
            state = 2;
        }

        return false;
    }

    /** @dev функция отправки денег обратно спонсорам
      */
    function getRefund() public returns (bool) {
        require(state == 1);
        require(contributions[msg.sender] > 0);

        uint amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;

        if (!msg.sender.send(amountToRefund)) {
            contributions[msg.sender] = amountToRefund;
            return false;
        } else {
            currentBalance = currentBalance - amountToRefund;
        }

        return true;
    }

    /** @dev функция для отправки подробной информации о проекте
      * @return возвращает все детали проекта
      */
    function getDetails() public view returns(address payable projectStarter, string memory projectTitle, string memory projectDesc, uint256 deadline, uint currentState, uint256 currentAmount, uint256 goalAmount) {
        projectStarter = creator;
        projectTitle = title;
        projectDesc = description;
        deadline = raiseBy;
        currentState = state;
        currentAmount = currentBalance;
        goalAmount = amountGoal;
    }
}