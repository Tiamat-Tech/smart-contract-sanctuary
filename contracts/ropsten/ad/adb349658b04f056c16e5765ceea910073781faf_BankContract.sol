/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.7;

contract BankContract
{
    address payable owner;                                 // адрес владельца банка
    uint BankBalance;
    mapping(address => bool) stuff;                        // словарь работников банка
    mapping(address => string) resumes;                    // словарь резюме(для тех, кто хочет стать соотрудником)
    mapping(address => string) creditApplications;         // словарь с людьми, ожидающими выдачи кредита
    int[3][] tariffes;                                      // Список кредитных тарифов

    mapping(address => mapping(string => int)) CreditsInfo; // Хранит в себе всю информацию про взявших кредит
                                                            // "TookCredit" - взят ли кредит
                                                            // "CreditSummary" - Сумма, оставшаяся к выплате
                                                            // "MonthPayment" - ежемесячная выплата по кредиту
                                                            // "Percent" - начисляемый банком ежемесячный процент по кредиту

    modifier StuffOnly()    // модификатор для соотрудников банка
    {
        require(stuff[msg.sender]);
        _;
    }

    modifier OwnerOnly()    // модификатор владельца банка
    {
        require(msg.sender == owner);
        _;
    }

    receive() external payable {                                 // Получение месячной платы
        require(CreditsInfo[msg.sender]["TookCredit"] == 1);
        int Received = int(address(this).balance - BankBalance);
        BankBalance = address(this).balance;
        require(Received >= CreditsInfo[msg.sender]["MonthPayment"]);
        CreditsInfo[msg.sender]["CreditSummary"] -= Received;
        if(CreditsInfo[msg.sender]["CreditSummary"] <= 0){
            CreditsInfo[msg.sender]["TookCredit"] = 0;
            CreditsInfo[msg.sender]["MonthPayment"] = 0;
            CreditsInfo[msg.sender]["CreditSummary"] = 0;
            CreditsInfo[msg.sender]["Percent"] = 0;
        }
        else{
            CreditsInfo[msg.sender]["CreditSummary"] = int(CreditsInfo[msg.sender]["CreditSummary"]*(1 + CreditsInfo[msg.sender]["Percent"]) / 100);
        }
    }

    constructor()
    {
        owner = payable(msg.sender);
        stuff[owner] = true;
        BankBalance = address(this).balance;
        BaseTariffes();        
    }

    function BaseTariffes() private{                         // Подключаются базовые тарифы(придуманные владельцем банка)
        tariffes.push([int(100), 10, 10]);
        tariffes.push([int(1000), 10, 100]);
        tariffes.push([int(10000), 10, 1000]);
        /*
        tariffes.push();
        tariffes[0] = new int[](3);
        tariffes[0][0] = 100;
        tariffes[0][1] = 10;
        tariffes[0][2] = 10;
        tariffes[1] = new int[](3);
        tariffes[1][0] = 1000;
        tariffes[1][1] = 10;
        tariffes[1][2] = 100;
        tariffes[2] = new int[](3);
        tariffes[2][0] = 10000;
        tariffes[2][1] = 10;
        tariffes[2][2] = 1000;*/
    }

    function StuffApplication(string memory resume) external {        // Позволяет направлять резюме владельцу банка
        resumes[msg.sender] = resume;
    }

    function CreditApplication(string memory resume) external {        // Функция для приема запросов на выдачу кредита
        creditApplications[msg.sender] = resume;
    }

    function DeleteStuff(address[] memory arr) public OwnerOnly{     // Удаление работников
        for(uint i = 0; i<arr.length; i++){
            stuff[arr[i]] = false;
        }
    }

    function ResumeCheck(address[] memory checked, bool[] memory answers) public OwnerOnly {    //Решение о приеме/не приеме на работу
        require(answers.length == checked.length);
        for(uint i=0; i<answers.length; i++){
            stuff[checked[i]] = answers[i];
        }
    }

    function AddTariff(int[3] memory conditions) public OwnerOnly {              // Добавление нового кредитного тарифа по условиям тарифа
        /*
        uint number = tariffes.length;
        tariffes[number] = new int[](3);
        tariffes[number][0] = conditions[0];
        tariffes[number][1] = conditions[1];
        tariffes[number][2] = conditions[2];
        */
        tariffes.push(conditions);
    }

    function DeleteTariff(int tariffnumber) public OwnerOnly {                    // Удаление кредитного тарифа по номеру
        if(tariffnumber != int(tariffes.length - 1)){
            for(uint i = uint(tariffnumber); i<tariffes.length - 1; i++){
                tariffes[i][0] = tariffes[i+1][0];
                tariffes[i][1] = tariffes[i+1][1];
                tariffes[i][2] = tariffes[i+1][2];
            }
        }
        tariffes.pop();
    }

    function CreditDecision(address payable [] memory checked, bool[] memory answers, uint[] memory tariffnumbers) public payable StuffOnly{   //Выдача кредитов
                                                                                                                                //Вызов достпен только соотрудникам банка
        require(answers.length == checked.length);
        require(tariffnumbers.length == checked.length);
        for(uint i=0; i<answers.length; i++){
            if(answers[i]){
                CreditsInfo[checked[i]]["TookCredit"] = 1;
                CreditsInfo[checked[i]]["CreditSummary"] = tariffes[tariffnumbers[i]][0];
                CreditsInfo[checked[i]]["Percent"] = tariffes[tariffnumbers[i]][1];
                CreditsInfo[checked[i]]["MonthPayment"] = tariffes[tariffnumbers[i]][2];
                checked[i].transfer(uint(tariffes[tariffnumbers[i]][0]));
            }
        }
    }

    function GetTariffes() public view returns( int[3][] memory){
        return tariffes;
    }
    
    function GetBalance() public view returns( uint ){
        return BankBalance;
    }

}