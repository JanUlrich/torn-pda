import * as admin from "firebase-admin";

export async function sendEnergyNotification(userStats: any, subscriber: any) {
  const energy = userStats.energy;
  const promises: Promise<any>[] = [];

  if (
    energy.maximum === energy.current && 
    (subscriber.energyLastCheckFull === false)
  ) {
    promises.push(
      sendNotificationToUser(
        subscriber.token,
        "Full Energy Bar",
        "Your energy is full, go spend on something!"
      )
    );
    promises.push(
      admin
        .firestore()
        .collection("players")
        .doc(subscriber.uid)
        .update({
          energyLastCheckFull: true,
        })
    );
  }

  if (
    energy.current < energy.maximum &&
    (subscriber.energyLastCheckFull === true)
  ) {
    promises.push(
      admin
        .firestore()
        .collection("players")
        .doc(subscriber.uid)
        .update({
          energyLastCheckFull: false,
        })
    );
  }

  return Promise.all(promises);
}

export async function sendTravelNotification(userStats: any, subscriber: any) {
  const travel = userStats.travel;
  const promises: Promise<any>[] = [];
  const lastTravelNotificationSent = subscriber.lastTravelNotified || 0;

  var currentDateInMillis = Date.now();

  if (
    travel.time_left > 0 &&
    travel.time_left <= 180 &&
    currentDateInMillis - lastTravelNotificationSent > 180 * 1000
  ) {
    promises.push(
      sendNotificationToUser(
        subscriber.token,
        `Approaching ${travel.destination}!`,
        `You are about to land in ${travel.destination}!`
      )
    );
    promises.push(
      admin
        .firestore()
        .collection("players")
        .doc(subscriber.uid)
        .update({
          lastTravelNotified: currentDateInMillis,
        })
    );
  }
  return Promise.all(promises);
}

export async function sendNotificationToUser(
  token: string,
  title: string,
  body: string
): Promise<any> {
  // This will send notification to the registered user, notification will only be shown if the app is on background or terminated, when the app is on screen
  // Notification will come as a callback, letting us do whatever we want with it.
  
  var payload = {
    notification: {
      title: title,
      body: body
    }
  };

  var options = {
    priority: 'high',
    timeToLive: 60 * 60 * 24
  };

  return admin.messaging()
    .sendToDevice(token, payload, options);
  
}
