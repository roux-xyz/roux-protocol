import { defineConfig } from '@wagmi/cli';
import { foundry } from '@wagmi/cli/plugins';

// run `npx wagmi generate` to generate types
export default defineConfig({
  out: 'abis/generatedAbis.ts',
  plugins: [
    foundry({
      project: './',
      include: [
        'Registry.sol/**',
        'Controller.sol/**',
        'RouxEdition.sol/**',
        'Collection.sol/**',
        'SingleEditionCollection.sol/**',
        'MultiEditionCollection.sol/**',
        'RouxEditionFactory.sol/**',
        'CollectionFactory.sol/**',
      ],
    }),
  ],
});
