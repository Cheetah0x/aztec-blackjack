import { AccountWalletWithSecretKey, Contract } from "@aztec/aztec.js";

export interface Expense {
  id: number;
  description: string;
  amount: Number | String;
  paidBy: string;
  to?: string;
  type: "expense" | "payment" | "balance_set";
}

export interface Group {
  name: string;
  members: string[];
}

export interface WalletDetails {
  wallet: AccountWalletWithSecretKey;
}

export interface MemberWallets {
  [memberName: string]: WalletDetails;
}

export interface MemberContracts {
  [memberName: string]: { walletInstance: Contract };
}

export interface Balances {
  [member: string]: {
    [otherMember: string]: number;
  };
}
