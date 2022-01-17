// セマンティックバージョニングを使用してSolidityのバージョンを指定
// 詳細: https://solidity.readthedocs.io/en/v0.5.10/layout-of-source-files.html#pragma
pragma solidity >=0.7.3;

// HelloWorldという名前のコントラクトを定義
// コントラクトは関数とデータ（その状態）のコレクションで、デプロイされるとコントラクトはイーサリアムブロックチェーン特定のアドレスに存在する
// 詳細: https://solidity.readthedocs.io/en/v0.5.10/structure-of-a-contract.html
contract HelloWorld {

   // 更新関数が呼び出されたときに発行される
   // スマートコントラクトイベントはブロックチェーンで何かが発生したことをアプリのフロントエンドに通知する
   // これにより、特定のイベントをリッスンし発生したときにアクションを実行できる
   event UpdatedMessages(string oldStr, string newStr);

   // 文字列型の状態変数messageをmessageを宣言
   // 状態変数は値がコントラクトストレージに永続的に保持される変数
   // publicはコントラクトの外部から変数にアクセス出来るようにし、他のコントラクトまたはクライアントが値にアクセスするために呼び出すことができる関数を作成する
   string public message;

   // 多くのクラスベースのオブジェクト指向言語と同様に、コンストラクタはコントラクトの作成時のみ実行される
   // 詳細: https://solidity.readthedocs.io/en/v0.5.10/contracts.html#constructors
   constructor(string memory initMessage) {
      // 文字列引数initMessageを受け取り、その値をコントラクトのmessageストレージ変数に設定する
      message = initMessage;
   }

   // 文字列引数を受取り、messageストレージ変数を更新するpublic関数
   function update(string memory newMessage) public {
      string memory oldMsg = message;
      message = newMessage;
      emit UpdatedMessages(oldMsg, newMessage);
   }
}