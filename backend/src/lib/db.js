import { MongoClient } from 'mongodb';

let client;
let clientPromise;

export async function getDb() {
  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('Missing MONGODB_URI');

  if (!clientPromise) {
    client = new MongoClient(uri, {
      maxPoolSize: 5,
      serverSelectionTimeoutMS: 3000,
      appName: 'optimum-backend',
    });
    clientPromise = client.connect();
  }

  const connected = await clientPromise;
  const db = connected.db('optimum');
  return db;
}
