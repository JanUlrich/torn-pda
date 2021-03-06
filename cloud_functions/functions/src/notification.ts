import * as admin from "firebase-admin";

export async function sendEnergyNotification(userStats: any, subscriber: any) {
  const energy = userStats.energy;
  const promises: Promise<any>[] = [];

  try {
    if (
      energy.maximum === energy.current && 
      (subscriber.energyLastCheckFull === false)
    ) {
      promises.push(
        sendNotificationToUser(
          subscriber.token,
          "Full Energy Bar",
          "Your energy is full, go spend on something!",
          "notification_energy",
          "#00FF00"
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

  } catch (error) {
    console.log("ERROR ENERGY");
    console.log(subscriber.uid);
    console.log(error);
  }

  return Promise.all(promises);
}

export async function sendNerveNotification(userStats: any, subscriber: any) {
  const nerve = userStats.nerve;
  const promises: Promise<any>[] = [];

  try {
    if (
      nerve.maximum === nerve.current && 
      (subscriber.nerveLastCheckFull === false)
    ) {
      promises.push(
        sendNotificationToUser(
          subscriber.token,
          "Full Nerve Bar",
          "Your nerve is full, go crazy!",
          "notification_nerve",
          "#FF0000"
        )
      );
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            nerveLastCheckFull: true,
          })
      );
    }

    if (
      nerve.current < nerve.maximum &&
      (subscriber.nerveLastCheckFull === true)
    ) {
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            nerveLastCheckFull: false,
          })
      );
    }

  } catch (error) {
    console.log("ERROR NERVE");
    console.log(subscriber.uid);
    console.log(error);
  }

  return Promise.all(promises);
}

export async function sendTravelNotification(userStats: any, subscriber: any) {
  const travel = userStats.travel;
  const promises: Promise<any>[] = [];
  const lastTravelNotificationSent = subscriber.lastTravelNotified || 0;

  const currentDateInMillis = Date.now();

  try {
    if (
      travel.time_left > 0 &&
      travel.time_left <= 240 &&
      currentDateInMillis - lastTravelNotificationSent > 300 * 1000
    ) {
      promises.push(
        sendNotificationToUser(
          subscriber.token,
          `Approaching ${travel.destination}!`,
          `You are about to land in ${travel.destination}!`,
          "notification_travel",
          "#0000FF"
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

  } catch (error) {
    console.log("ERROR TRAVEL");
    console.log(subscriber.uid);
    console.log(error);
  }

  return Promise.all(promises);
}

export async function sendHospitalNotification(userStats: any, subscriber: any) {
  const promises: Promise<any>[] = [];
  
  const currentDateInMillis = Math.floor(Date.now() / 1000);
  
  let hospitalTimeToRelease = userStats.states.hospital_timestamp - currentDateInMillis;
  if (hospitalTimeToRelease < 0)
    hospitalTimeToRelease = 0;

  const hospitalLastStatus = subscriber.hospitalLastStatus || 'out';
  const status = userStats.last_action.status;

  try {

    // If we have just been hospitalised (stay > 180 seconds)
    if (
      hospitalTimeToRelease > 240 && hospitalLastStatus !== 'in'
    ) {
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            hospitalLastStatus: 'in',
          })
      );

      if (status !== 'Online') {
        promises.push(
          sendNotificationToUser(
            subscriber.token,
            `Hospital admission`,
            `You have been hospitalised!`,
            'notification_hospital',
            '#FFFF00'
          )
        );
      }
    }

    // If we are about to be released and last time we checked we were in hospital
    else if (
      hospitalTimeToRelease > 0 && hospitalTimeToRelease <= 240 &&
      hospitalLastStatus === 'in'
    ) {
    
      // Change last status so that we don't notify more than once
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            hospitalLastStatus: 'notified',
          })
      );

      if (status !== 'Online') {
        promises.push(
          sendNotificationToUser(
            subscriber.token,
            `Hospital time ending`,
            `You are about to be released from hospital, grab your things!`,
            'notification_hospital',
            '#FFFF00'
          )
        );
      }
    } 

    // If we are out and did not anticipate this, we have been revived  
    else if (
      hospitalTimeToRelease === 0 &&
      hospitalLastStatus === 'in'
    ) {
    
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            hospitalLastStatus: 'out',
          })
      );

      if (status !== 'Online') {
        promises.push(
          sendNotificationToUser(
            subscriber.token,
            `You are out of hospital!`,
            `You left hospital earlier than expected!`,
            'notification_hospital',
            '#FFFF00'
          )
        );
      }
    }
  
    // If we are out and already sent the notification, just update the status
    else if (
      hospitalTimeToRelease === 0 &&
      hospitalLastStatus === 'notified'
    ) {
      promises.push(
        admin
          .firestore()
          .collection("players")
          .doc(subscriber.uid)
          .update({
            hospitalLastStatus: 'out',
          })
      );
    }

  } catch (error) {
    console.log("ERROR HOSPITAL");
    console.log(subscriber.uid);
    console.log(error);
  }

  return Promise.all(promises);
}

export async function sendNotificationToUser(
  token: string,
  title: string,
  body: string,
  icon: string,
  color: string,
): Promise<any> {
  
  const payload = {
    notification: {
      title: title,
      body: body,
      icon: icon,
      color: color,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      message: body, 
    },
  };

  const options = {
    priority: 'high',
    timeToLive: 60 * 60 * 5
  };

  return admin.messaging()
    .sendToDevice(token, payload, options);
  
}
