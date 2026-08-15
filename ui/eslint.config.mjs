import nextVitals from 'eslint-config-next/core-web-vitals';
import nextTypeScript from 'eslint-config-next/typescript';

const config = [
  ...nextVitals,
  ...nextTypeScript,
  { ignores: ['.next/**', 'coverage/**', 'dist/**'] },
  {
    rules: {
      // Effects here bridge API/localStorage state into client components.
      'react-hooks/set-state-in-effect': 'off',
    },
  },
];

export default config;
