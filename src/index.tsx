import './globals.css';
import 'react-toastify/dist/ReactToastify.css';
import * as ReactDOM from 'react-dom/client';
import * as React from 'react';
import Game from './pages/game';
import { AztecAccountProvider } from './contexts/AztecAccountContext';

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement);
root.render(
  <>
    <AztecAccountProvider>
      <Game />
    </AztecAccountProvider>
  </>,
);