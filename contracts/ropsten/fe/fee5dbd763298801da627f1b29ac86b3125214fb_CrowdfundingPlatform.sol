// SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.8.7;

import "./multi.sol";

contract CrowdfundingPlatform{
    mapping(uint => address) projects;  // Словарь сборов по владельцам
    mapping(address => uint) idByAddress;  // Словарь сборов по владельцам
    mapping(address => address[]) addressByOwner;  // Словарь сборов по владельцам
    uint fundraisingId=1;

    modifier existOnly(uint _id){
        require(_id != 0 && _id < fundraisingId);
        _;
    }

    // Функция возвращает полную информацию о сборе
    function getInfo(uint _id)public view existOnly(_id) returns(iFundraising.Info memory){
        return iFundraising(projects[_id]).getInfo();
    }

    // Функция возвращает массив всех сборов, созданных владельцом адреса
    function getAllBy(address _add)public view returns(address[] memory){
        return addressByOwner[_add];
    }

    // Функция возвращает id сбора по его адресу
    function getId(address _add)public view returns(uint){
        return idByAddress[_add];
    }
    
    // Функция создаёт новый единоразовый сбор пожертвований
    function createSingleFundraising(string calldata _title, string calldata _desc, string calldata _cont, uint _target, uint _duration)public{
        SingleFundraising proj = new SingleFundraising();
        proj.init(msg.sender, _title, _desc, _cont, _target, _duration);
        proj.activate(msg.sender);
        projects[fundraisingId] = address(proj);
        addressByOwner[msg.sender].push(address(proj));
        idByAddress[address(proj)] = fundraisingId++;
    }

    // Функция создаёт новый многоразовый сбор пожертвований
    function createMultiFundraising(string calldata _title, string calldata _desc, string calldata _cont, uint _target, uint _duration)public{
        MultiFundraising proj = new MultiFundraising();
        proj.init(msg.sender, _title, _desc, _cont, _target, _duration);
        proj.activate(msg.sender);
        projects[fundraisingId] = address(proj);
        addressByOwner[msg.sender].push(address(proj));
        idByAddress[address(proj)] = fundraisingId++;
    }

    // Функция пытается вывести собранный эфир на адрес владельца
    // В случае успеха, останавливает дальнейший сбор
    function getCollected(uint _id)public existOnly(_id){
        iFundraising(projects[_id]).getAll(msg.sender);
    }

    // Функция возвращает собранный эфир, если цель оказалась не выполнена
    function returnCollected(uint _id)public existOnly(_id){
        iFundraising(projects[_id]).returnAll();
    }

    // Функция жертвования эфира
    function donate(uint _id)public existOnly(_id) payable{
        iFundraising(projects[_id]).addDonation{value: msg.value}(msg.sender);
    }

    // Функция запуска следующего сбора
    function activateNextCycle(uint _id)public existOnly(_id){
        iFundraising(projects[_id]).activate(msg.sender);
    }

    // Функция пытается изменить название сбора пожертвований
    function setTitle(uint _id, string calldata _title)public existOnly(_id){
        iFundraising(projects[_id]).setTitle(_title, msg.sender);
    }

    // Функция пытается изменить описание сбора пожертвований
    function setDescription(uint _id, string calldata _desc)public existOnly(_id){
        iFundraising(projects[_id]).setDescription(_desc, msg.sender);
    }

    // Функция пытается изменить контакты автора сборов
    function setContacts(uint _id, string calldata _cont)public existOnly(_id){
        iFundraising(projects[_id]).setContacts(_cont, msg.sender);
    }

    // Функция пытается изменить цель сбора пожертвований
    function setTarget(uint _id, uint _target)public existOnly(_id){
        iFundraising(projects[_id]).setDuration(_target, msg.sender);
    }

    // Функция пытается изменить длительность сбора пожертвований
    function setDuration(uint _id, uint _duration)public existOnly(_id){
        iFundraising(projects[_id]).setDuration(_duration, msg.sender);
    }
}