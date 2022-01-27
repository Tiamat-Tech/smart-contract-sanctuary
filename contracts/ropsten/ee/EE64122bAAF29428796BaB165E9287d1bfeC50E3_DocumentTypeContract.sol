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

    mapping(string => DocumentTypeValue) private documentTypes;

    string[] private materialCertificationDocumentTypes;
    string[] private scopeCertificationDocumentTypes;
    string[] private selfCertificationDocumentTypes;
    string[] private transactionCertificationDocumentTypes;
    string[] private contractCertificationDocumentTypes;
    string[] private orderCertificationDocumentTypes;
    string[] private shippingCertificationDocumentTypes;

    event DocumentTypeAdded();

    function addDocumentType(string memory code, string memory name, string memory description) public {
        documentTypes[code] = DocumentTypeValue({name: name, description: description});
    }

    function addMaterialCertificationDocumentType(string memory code) public {
        materialCertificationDocumentTypes.push(code);
    }

    function addScopeCertificationDocumentType(string memory code) public {
        scopeCertificationDocumentTypes.push(code);
    }

    function addSelfCertificationDocumentType(string memory code) public {
        selfCertificationDocumentTypes.push(code);
    }

    function addTransactionCertificationDocumentType(string memory code) public {
        transactionCertificationDocumentTypes.push(code);
    }

    function addContractDocumentType(string memory code) public {
        contractCertificationDocumentTypes.push(code);
    }

    function addOrderDocumentType(string memory code) public {
        orderCertificationDocumentTypes.push(code);
    }

    function addShippingDocumentType(string memory code) public {
        shippingCertificationDocumentTypes.push(code);
    }

    function getMaterialCertificationDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(materialCertificationDocumentTypes);
    }

    function getScopeCertificationDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(scopeCertificationDocumentTypes);
    }

    function getSelfCertificationDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(selfCertificationDocumentTypes);
    }

    function getTransactionCertificationDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(transactionCertificationDocumentTypes);
    }

    function getContractDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(contractCertificationDocumentTypes);
    }

    function getOrderDocumentTypes() public view returns (DocumentType[] memory) {
        return fromCodesToDocumentTypes(orderCertificationDocumentTypes);
    }

    function getShippingDocumentTypes() public view returns (DocumentType[] memory) {
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


}