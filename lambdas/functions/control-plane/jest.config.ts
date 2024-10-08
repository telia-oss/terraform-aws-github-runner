import type { Config } from 'jest';

import defaultConfig from '../../jest.base.config';

const config: Config = {
  ...defaultConfig,
  coverageThreshold: {
    global: {
<<<<<<< HEAD
      statements: 97.86,
      branches: 96.68,
      functions: 95.95,
      lines: 97.8,
=======
      statements: 97.99,
      branches: 96.04,
      functions: 97.53,
      lines: 98.3,
>>>>>>> main
    },
  },
};

export default config;
