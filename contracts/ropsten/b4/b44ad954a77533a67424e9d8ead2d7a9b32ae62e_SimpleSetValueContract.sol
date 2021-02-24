/**
 *Submitted for verification at Etherscan.io on 2021-02-24
*/

/*
Generated by Jthereum BETA version!
┌──────────────┬──────────────────────────────┐
│     Atribute │                        Value │
├──────────────┼──────────────────────────────┤
│      Version │           2.1.3.387.release1 │
│         Beta │                         true │
│ Build Number │                          387 │
│   Build Date │ Sun Sep 13 13:45:51 EDT 2020 │
│   Short Hash │                 680c61b5f987 │
│ Installation │ 0xe03795930fa86ef1aa9d66a72c │
└──────────────┴──────────────────────────────┘

*/
pragma solidity ^0.5.9;

contract SimpleSetValueContract
{
	int32 private value;
	function setValue(int32 newValue) public 
	{
		value = newValue;
	}
	function getValue() public view returns (int32) 
	{
		return value;
	}

	}

/*
 * Below is the original Java source used as input to Jthereum.
 * To regenerate the exact Java source files, remove all below single line
 * comments that start at column zero, and place the source in the indicated file.
 */

/*
 * Source for class com.u7.jthereum.exampleContracts.SimpleSetValueContract
 * File Path: ./providedSource/com/u7/jthereum/exampleContracts/SimpleSetValueContract.java
 */

// package com.u7.jthereum.exampleContracts;
// 
// import com.u7.jthereum.*;
// import com.u7.jthereum.annotations.*;
// 
// import static com.u7.jthereum.Jthereum.*;
// 
// public class SimpleSetValueContract implements ContractProxyHelper
// {
// 	private int value;
// 
// 	public void setValue(final int newValue)
// 	{
// 		value = newValue;
// 	}
// 
// 	@View
// 	public int getValue()
// 	{
// 		return value;
// 	}
// 
// 	public static void main(final String[] args)
// 	{
// 		compileAndDeploy("ropsten");
// 
// 		// Get the proxy for the deployed contract
// /*		final SimpleSetValueContract a = createProxy(SimpleSetValueContract.class);
// 
// ///		a.setValue(7);
// 
// 		final int value = a.getValue();
// 
// 		p("Got value: " + value);
// */
// 	}
// }