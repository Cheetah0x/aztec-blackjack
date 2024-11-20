import React from 'react';

interface PopupProps {
  isOpen: boolean;
  onClose: () => void;
  children: React.ReactNode;
}

const Popup = ({ isOpen, onClose, children }: PopupProps) => {
  if (!isOpen) return null;

  return (
    <div 
      className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="bg-[#333333] p-8 rounded-lg max-w-2xl w-full max-h-[80vh] overflow-y-auto text-[#f2f2f2]">
        <button 
          onClick={onClose}
          className="float-right text-gray-400 hover:text-white"
        >
          Close
        </button>
        <div className="clear-both">
          {children}
        </div>
      </div>
    </div>
  );
};

export default Popup;