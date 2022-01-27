/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.4;
pragma experimental ABIEncoderV2;

contract DocumentTypeContract {

    struct DocumentType {
        string code;
        string name;
        string description;
    }

    struct DocumentTypeValue {
        string name;
        string description;
    }

    //    struct MaterialCertificationDocumentType {
    //        string code;
    //    }
    //
    //    struct ScopeCertificationDocumentType {
    //        string code;
    //    }
    //
    //    struct SelfCertificationDocumentType {
    //        string code;
    //    }
    //
    //    struct TransactionCertificationDocumentType {
    //        string code;
    //    }
    //
    //    struct ContractDocumentType {
    //        string code;
    //    }
    //
    //    struct OrderDocumentType {
    //        string code;
    //    }
    //
    //    struct ShippingDocumentType {
    //        string code;
    //    }

    address public owner;

    mapping(string => DocumentTypeValue) private documentTypes;

    string[] private materialCertificationDocumentTypes;
    string[] private scopeCertificationDocumentTypes;
    string[] private selfCertificationDocumentTypes;
    string[] private transactionCertificationDocumentTypes;
    string[] private contractCertificationDocumentTypes;
    string[] private orderCertificationDocumentTypes;
    string[] private shippingCertificationDocumentTypes;
    //    MaterialCertificationDocumentType[] public materialCertificationDocumentTypes;
    //    ScopeCertificationDocumentType[] public scopeCertificationDocumentTypes;
    //    SelfCertificationDocumentType[] public selfCertificationDocumentTypes;
    //    TransactionCertificationDocumentType[] public transactionCertificationDocumentTypes;
    //    ContractDocumentType[] public contractCertificationDocumentTypes;
    //    OrderDocumentType[] public orderCertificationDocumentTypes;
    //    ShippingDocumentType[] public shippingCertificationDocumentTypes;

    event DocumentTypeAdded();

    constructor()  {
        owner = msg.sender;
    }

    function addDocumentType(string memory code, string memory name, string memory description) public restricted {
        documentTypes[code] = DocumentTypeValue({name: name, description: description});
    }

    function addMaterialCertificationDocumentType(string memory code) public restricted {
        materialCertificationDocumentTypes.push(code);
    }

    function addScopeCertificationDocumentType(string memory code) public restricted {
        scopeCertificationDocumentTypes.push(code);
    }

    function addSelfCertificationDocumentType(string memory code) public restricted {
        selfCertificationDocumentTypes.push(code);
    }

    function addTransactionCertificationDocumentType(string memory code) public restricted {
        transactionCertificationDocumentTypes.push(code);
    }

    function addContractDocumentType(string memory code) public restricted {
        contractCertificationDocumentTypes.push(code);
    }

    function addOrderDocumentType(string memory code) public restricted {
        orderCertificationDocumentTypes.push(code);
    }

    function addShippingDocumentType(string memory code) public restricted {
        shippingCertificationDocumentTypes.push(code);
    }

    function getMaterialCertificationDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(materialCertificationDocumentTypes);
    }

    function getScopeCertificationDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(scopeCertificationDocumentTypes);
    }

    function getSelfCertificationDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(selfCertificationDocumentTypes);
    }

    function getTransactionCertificationDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(transactionCertificationDocumentTypes);
    }

    function getContractDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(contractCertificationDocumentTypes);
    }

    function getOrderDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(orderCertificationDocumentTypes);
    }

    function getShippingDocumentTypes() public restricted view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(shippingCertificationDocumentTypes);
    }


    function fromCodesToDocumentTypes(string[] memory codes) private view returns (DocumentType[] memory) {
        DocumentType[] memory result = new DocumentType[](codes.length);
        DocumentTypeValue memory docTypeValue;
        for (uint i=0; i<codes.length; i++) {
            docTypeValue = documentTypes[codes[i]];
            result[i] = DocumentType({code: codes[i], name: docTypeValue.name, description: docTypeValue.description});
        }
        return result;
    }

    modifier restricted() {
        require(msg.sender == owner, "The contract can be invoked only by the owner");
        _;
    }


}