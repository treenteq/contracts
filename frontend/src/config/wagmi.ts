import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { sepolia } from 'viem/chains'
import { http } from 'viem'

export const wagmiConfig = getDefaultConfig({
    appName: 'Dataset Marketplace',
    projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID as string,
    chains: [sepolia],
    transports: {
        [sepolia.id]: http()
    },
}) 