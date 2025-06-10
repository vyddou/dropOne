// Initialiser les notifications au chargement de la page
document.addEventListener('turbo:load', () => {
  // Vérifier s'il y a des notifications existantes au chargement
  const heartIcon = document.querySelector('.bi-suit-heart')
  const messageIcon = document.querySelector('.bi-chat-dots-fill')
  
  let totalNotifications = 0
  
  if (heartIcon && heartIcon.parentElement) {
    const heartBadge = heartIcon.parentElement.querySelector('.bg-danger')
    if (heartBadge) {
      totalNotifications += 1
    }
  }
  
  if (messageIcon && messageIcon.parentElement) {
    const messageBadge = messageIcon.parentElement.querySelector('.badge')
    if (messageBadge) {
      totalNotifications += 1
    }
  }
  
  // Mettre à jour le titre si nécessaire
  if (totalNotifications > 0) {
    const originalTitle = document.title.replace(/^\(\d+\)\s/, '') // Enlever le badge existant
    document.title = `(${totalNotifications}) ${originalTitle}`
  }
})