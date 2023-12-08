export const getMondayDate = (date = new Date()) => {
  const clonedDate = new Date(date.getTime());

  const numOfDays = ((7 - clonedDate.getDay()) % 7 + 1) % 7;
  const newDate = clonedDate.getDate() + numOfDays;

  return clonedDate.setDate(newDate);
};
