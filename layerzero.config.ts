import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const optimism_sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.OPTSEP_V2_TESTNET,
    contractName: 'MyOApp',
}

const base_sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.BASESEP_V2_TESTNET,
    contractName: 'MyOApp',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: optimism_sepoliaContract,
        },
        {
            contract: base_sepoliaContract,
        }
    ],
    connections: [
        {
            from: optimism_sepoliaContract,
            to: base_sepoliaContract,
        },
        {
            from: base_sepoliaContract,
            to: optimism_sepoliaContract,
        }
    ],
}

export default config
