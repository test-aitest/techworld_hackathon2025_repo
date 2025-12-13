import { Request, Response } from 'express';

export const listen = (req: Request, res: Response): void => {
  res.json({ message: 'Listening...' });
};

